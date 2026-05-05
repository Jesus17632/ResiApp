//
//  CapturaViewModel.swift
//  ResiApp
//
//  State machine que coordina:
//  - Permiso de cámara
//  - Sesión AVCapture en vivo
//  - Detección por frame (ManureDetector) con debounce
//  - Disparo automático del clasificador pesado (AppleIntelligenceClassifier)
//  - Persistencia de la pila en SwiftData
//
//  Adaptado del patrón de InventoryViewModel de Tlane, con cambios:
//  - El "objeto detectado" no es una categoría, es un bounding box que el
//    overlay sigue en tiempo real.
//  - Tras lock-on, el flujo va a `analyzing` automáticamente (no hay sheet
//    de confirmación intermedia como en Tlane).
//  - Soporta una rama paralela de "imagen cargada desde galería" que salta
//    directo a `analyzing`.
//

import Foundation
import SwiftData
import AVFoundation
import UIKit
import CoreVideo
import CoreLocation

@MainActor
enum CapturaState {
    case requestingPermission
    case denied
    /// Cámara en vivo, buscando objetivo. El detector reporta detección
    /// para decidir CUÁNDO disparar (no se usa para pintar — el recuadro es estático).
    case scanning(lastDetection: DetectionResult)
    /// Objetivo confirmado y estable. Se está congelando el frame y arrancando IA.
    /// El `box` se conserva por compatibilidad / debug pero la UI no lo dibuja.
    case locking(box: CGRect, confidence: Double)
    /// IA pesada corriendo (Vision + Foundation Models).
    case analyzing(frame: UIImage)
    /// Resultado listo. La pila ya está en SwiftData en `pendingAnalysis` o lo que decida la IA.
    case result(ManureClassification, frame: UIImage)
    /// Error recuperable (modelo no disponible, etc.). El frame queda visible.
    case error(message: String, frame: UIImage?)
}

@Observable
@MainActor
final class CapturaViewModel: NSObject {

    // MARK: - Inputs

    private let context: ModelContext
    private let classifier: any ManureClassifierService
    private let locationProvider: () -> CLLocationCoordinate2D

    // MARK: - Estado expuesto

    var state: CapturaState = .requestingPermission

    /// La pila creada cuando arrancó el análisis. Se actualiza con el resultado.
    /// La vista la usa para el botón "Publicar en marketplace".
    private(set) var pileEnAnalisis: ManurePile?

    /// Última detección (box + confianza) que la vista usa para pintar el overlay
    /// 60fps mientras el state es `.scanning`.
    var lastDetection: DetectionResult = .none

    // MARK: - Camera plumbing

    let cameraSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "resiapp.camera.session")

    // Tlane usaba `nonisolated(unsafe)` para acceder a estos desde el callback
    // de AVCapture (que es nonisolated). Mantenemos ese patrón.
    nonisolated(unsafe) private var lastFrameAnalyzedAt: Date = .distantPast
    nonisolated(unsafe) private var isAnalyzingFrame: Bool = false
    nonisolated(unsafe) private var isScanningActive: Bool = false
    nonisolated(unsafe) private var scanningEpoch: Int = 0

    /// Último UIImage construido a partir del visor. Se usa como fallback para
    /// `captureManually()` (atajo "shutter"), por si el detector automático
    /// no está disparando.
    nonisolated(unsafe) private var latestFrame: UIImage?

    /// Cuándo empezamos a ver detecciones positivas continuas (para debounce de 1.2s).
    private var stableSince: Date?
    private var stableBox: CGRect?

    // MARK: - Init

    init(
        context: ModelContext,
        classifier: any ManureClassifierService,
        locationProvider: @escaping () -> CLLocationCoordinate2D
    ) {
        self.context = context
        self.classifier = classifier
        self.locationProvider = locationProvider
        super.init()
    }

    // MARK: - Permiso

    func requestCameraPermission() async {
        #if targetEnvironment(simulator)
        // En simulador no hay cámara → la vista mostrará el botón de galería,
        // y la rama de live se queda en .scanning (vista negra).
        state = .scanning(lastDetection: .none)
        isScanningActive = true
        scanningEpoch += 1
        return
        #else
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupSessionIfNeeded()
            state = .scanning(lastDetection: .none)
            isScanningActive = true
            scanningEpoch += 1
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                setupSessionIfNeeded()
                state = .scanning(lastDetection: .none)
                isScanningActive = true
                scanningEpoch += 1
            } else {
                state = .denied
            }
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .denied
        }
        #endif
    }

    // MARK: - Camera lifecycle

    func startCamera() {
        clearDebounce()
        isScanningActive = true
        scanningEpoch += 1
        sessionQueue.async { [weak self] in
            guard let session = self?.cameraSession, !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stopCamera() {
        isScanningActive = false
        scanningEpoch += 1
        clearDebounce()
        sessionQueue.async { [weak self] in
            guard let session = self?.cameraSession, session.isRunning else { return }
            session.stopRunning()
        }
    }

    /// Vuelve al estado `.scanning` y reanuda la cámara. Se usa después de un
    /// resultado o de un error, cuando el usuario aprieta "Tomar otra foto".
    func resetToScanning() {
        pileEnAnalisis = nil
        lastDetection = .none
        clearDebounce()
        state = .scanning(lastDetection: .none)
        startCamera()
    }

    // MARK: - Setup interno

    private var sessionConfigured = false

    private func setupSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true

        sessionQueue.async { [weak self] in
            guard let self else { return }
            cameraSession.beginConfiguration()
            cameraSession.sessionPreset = .high

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  cameraSession.canAddInput(input) else {
                cameraSession.commitConfiguration()
                return
            }
            cameraSession.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: sessionQueue)
            output.alwaysDiscardsLateVideoFrames = true
            if cameraSession.canAddOutput(output) {
                cameraSession.addOutput(output)
            }

            cameraSession.commitConfiguration()
            cameraSession.startRunning()
        }
    }

    private func clearDebounce() {
        stableSince = nil
        stableBox = nil
        lastFrameAnalyzedAt = .distantPast
    }

    // MARK: - Rama "elegir de galería"

    /// Salto directo a `.analyzing` con una imagen ya seleccionada por el usuario.
    /// No pasa por el detector ligero — ya hay imagen, ya hay intención.
    func analyzeFromGallery(uiImage: UIImage) {
        stopCamera()
        state = .analyzing(frame: uiImage)
        Task { await runHeavyClassifier(on: uiImage) }
    }

    /// Atajo manual: el usuario aprieta el shutter aunque el detector automático
    /// no haya disparado. Usamos el último frame que cacheamos del visor.
    /// Si no tenemos nada (cámara recién iniciada), no hacemos nada.
    func captureManually() {
        guard case .scanning = state, let frame = latestFrame else { return }
        stopCamera()
        state = .analyzing(frame: frame)
        Task { await runHeavyClassifier(on: frame) }
    }

    // MARK: - Lock-on → análisis pesado

    /// Cuando el detector ligero confirma estabilidad por > 1.2s, transicionamos
    /// a `.locking` (overlay verde sólido, ~400ms de animación) y luego disparamos
    /// el clasificador pesado.
    private func lockOn(box: CGRect, confidence: Double, frame: UIImage) async {
        state = .locking(box: box, confidence: confidence)
        stopCamera()

        // Pequeña pausa para que el usuario vea el lock visualmente.
        try? await Task.sleep(for: .milliseconds(450))

        guard !Task.isCancelled else { return }
        state = .analyzing(frame: frame)
        await runHeavyClassifier(on: frame)
    }

    private func runHeavyClassifier(on uiImage: UIImage) async {
        // Persistimos el JPEG primero. Si la IA falla, igual queda registrado
        // como pendingAnalysis (mismo contrato que tenía CapturaView original).
        guard let jpeg = uiImage.jpegData(compressionQuality: 0.85) else {
            state = .error(message: "No se pudo procesar la imagen.", frame: uiImage)
            return
        }
        let fileName = "pile_\(UUID().uuidString).jpg"
        if let url = documentsURL()?.appendingPathComponent(fileName) {
            try? jpeg.write(to: url)
        }

        let coord = locationProvider()
        let pile = ManurePile(
            fecha: .now,
            volumenM3: 0,
            humedadPct: 0,
            latitud: coord.latitude,
            longitud: coord.longitude,
            fotoFileName: fileName,
            audioTranscripcion: nil,
            syncStatus: .pendingAnalysis
        )
        context.insert(pile)
        try? context.save()
        pileEnAnalisis = pile

        do {
            let classification = try await classifier.classify(imageData: jpeg)
            pile.humedadPct = classification.humedadPct
            pile.volumenM3 = classification.volumenEstimadoM3
            try? context.save()
            state = .result(classification, frame: uiImage)
        } catch let error as ClassifierError {
            switch error {
            case .modelUnavailable(let reason):
                state = .error(message: reason, frame: uiImage)
            default:
                state = .error(message: error.localizedDescription, frame: uiImage)
            }
        } catch {
            state = .error(message: error.localizedDescription, frame: uiImage)
        }
    }

    // MARK: - Publicar

    func publicarEnMarketplace() {
        guard case let .result(classification, _) = state,
              classification.esApto,
              let pile = pileEnAnalisis else { return }
        pile.syncStatus = .available
        try? context.save()
        resetToScanning()
    }

    private func documentsURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
//
// Nota: este delegate corre en `sessionQueue` (background). Por eso cualquier
// acceso a `state` o a `lastDetection` lo hacemos vía `Task { @MainActor }`.

extension CapturaViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isScanningActive else { return }

        // Throttle: ~2 fps. Vision saliency + classify cuesta ~50–100ms en A17,
        // analizar cada frame es desperdicio.
        let now = Date()
        guard now.timeIntervalSince(lastFrameAnalyzedAt) >= 0.5,
              !isAnalyzingFrame else { return }
        lastFrameAnalyzedAt = now
        isAnalyzingFrame = true

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isAnalyzingFrame = false
            return
        }

        // Preservamos el frame por si terminamos haciendo lock-on con él,
        // o por si el usuario aprieta el shutter manual.
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let ciContext = CIContext()
        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        let uiImage = cgImage.map { UIImage(cgImage: $0, scale: 1.0, orientation: .right) }
        latestFrame = uiImage

        let epochAtStart = scanningEpoch

        Task { [weak self] in
            guard let self else { return }
            let result = await ManureDetector.detect(in: pixelBuffer)
            await self.handleFrame(result: result, frame: uiImage, expectedEpoch: epochAtStart)
            self.isAnalyzingFrame = false
        }
    }

    private func handleFrame(
        result: DetectionResult,
        frame: UIImage?,
        expectedEpoch: Int
    ) async {
        // Si el usuario salió de scanning mientras detectábamos → descartar.
        guard isScanningActive,
              scanningEpoch == expectedEpoch else { return }
        guard case .scanning = state else { return }

        // Actualizar siempre lastDetection para que el overlay siga al objeto.
        lastDetection = result
        state = .scanning(lastDetection: result)

        // Lógica de debounce: para hacer lock-on necesitamos:
        //   1. Que haya bounding box
        //   2. Que isLikelyManure sea true
        //   3. Que la confianza compuesta supere 0.45
        //   4. Que el box no se mueva drásticamente entre frames (estabilidad)
        //   5. Que se mantenga así por 1.2s
        let now = Date()
        let qualifies = result.boundingBox != nil
            && result.isLikelyManure
            && result.confidence >= 0.45

        if qualifies, let box = result.boundingBox {
            if let prevBox = stableBox, boxesAreClose(box, prevBox) {
                // sigue siendo el mismo objetivo → revisar timing
                if let since = stableSince,
                   now.timeIntervalSince(since) >= 1.2,
                   let frame {
                    // ¡LOCK!
                    await lockOn(box: box, confidence: result.confidence, frame: frame)
                    return
                }
            } else {
                // Nuevo candidato — reiniciar timer
                stableBox = box
                stableSince = now
            }
        } else {
            // Perdimos el objetivo → reset.
            stableBox = nil
            stableSince = nil
        }
    }

    /// Considera dos boxes "el mismo objeto" si sus centros están suficientemente
    /// cerca. Coordenadas Vision (normalizadas 0..1).
    private nonisolated func boxesAreClose(_ a: CGRect, _ b: CGRect) -> Bool {
        let centerA = CGPoint(x: a.midX, y: a.midY)
        let centerB = CGPoint(x: b.midX, y: b.midY)
        let dx = centerA.x - centerB.x
        let dy = centerA.y - centerB.y
        let dist = (dx * dx + dy * dy).squareRoot()
        return dist < 0.15  // 15% de la pantalla en cualquier eje
    }
}
