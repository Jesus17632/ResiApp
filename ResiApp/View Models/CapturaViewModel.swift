//
//  CapturaViewModel.swift
//  ResiApp
//
//  Fixes aplicados en este pass:
//  [1] defer en el Task de captureOutput → isAnalyzingFrame se libera SIEMPRE
//  [2] Watchdog de 3s → reset forzado si el Task murió silenciosamente
//  [3] Copias locales de isScanningActive/scanningEpoch al inicio de captureOutput
//  [4] resetToScanning() resetea explícitamente los flags de frame
//  [5] CIContext como static let → se crea UNA SOLA VEZ (era el bug de crash/lag más grave)
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
    case scanning(lastDetection: DetectionResult)
    /// Lock-on. Cargamos el `frozenFrame` para que la View no intente
    /// dibujar el preview de cámara (ya está detenida en este punto).
    case locking(frozenFrame: UIImage, confidence: Double)
    case analyzing(frame: UIImage)
    case result(ManureClassification, frame: UIImage)
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
    private(set) var pileEnAnalisis: ManurePile?
    var lastDetection: DetectionResult = .none

    // MARK: - Camera plumbing

    let cameraSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "resiapp.camera.session")

    // nonisolated(unsafe): accedidas desde sessionQueue (captureOutput)
    // y escritas desde MainActor. Bool e Int en ARM64 son atómicamente
    // seguros para lecturas/escrituras simples.
    nonisolated(unsafe) private var lastFrameAnalyzedAt: Date   = .distantPast
    nonisolated(unsafe) private var isAnalyzingFrame: Bool      = false
    nonisolated(unsafe) private var isScanningActive: Bool      = false
    nonisolated(unsafe) private var scanningEpoch: Int          = 0
    nonisolated(unsafe) private var latestFrame: UIImage?

    // [2] Watchdog: si llevamos > 3s "analizando" un frame, el Task murió → reset forzado
    nonisolated(unsafe) private var frameAnalysisStartedAt: Date = .distantPast

    // [5] CIContext ESTÁTICO: se construye una sola vez para toda la vida del proceso.
    //     Antes se creaba en cada frame → causa directa de lag y crashes por OOM.
    nonisolated(unsafe) private static let ciContext = CIContext(
        options: [.useSoftwareRenderer: false]
    )

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
        // [fix re-entry] Limpiamos los flags de frame también aquí.
        // Antes solo se limpiaban en resetToScanning(), pero al cambiar
        // de tab → volver, no pasamos por resetToScanning() y los flags
        // quedaban "calientes" del estado anterior, causando freezes
        // intermitentes en la próxima sesión de escaneo.
        isAnalyzingFrame = false
        frameAnalysisStartedAt = .distantPast
        latestFrame = nil
        sessionQueue.async { [weak self] in
            guard let session = self?.cameraSession, session.isRunning else { return }
            session.stopRunning()
        }
    }

    /// [4] resetToScanning: reset explícito de los flags de frame para que nunca
    ///     queden colgados entre sesiones de escaneo.
    func resetToScanning() {
        pileEnAnalisis = nil
        lastDetection = .none
        clearDebounce()
        // [4] Garantía: aunque un Task anterior no haya terminado limpiamente,
        //     el próximo ciclo de escaneo empieza con flags en cero.
        isAnalyzingFrame = false
        frameAnalysisStartedAt = .distantPast
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

    // MARK: - Rama galería / shutter manual

    func analyzeFromGallery(uiImage: UIImage) {
        stopCamera()
        state = .analyzing(frame: uiImage)
        Task { await runHeavyClassifier(on: uiImage) }
    }

    func captureManually() {
        guard case .scanning = state, let frame = latestFrame else { return }
        stopCamera()
        state = .analyzing(frame: frame)
        Task { await runHeavyClassifier(on: frame) }
    }

    // MARK: - Lock-on → análisis pesado

    private func lockOn(box: CGRect, confidence: Double, frame: UIImage) async {
        // [importante] usamos el frame congelado para el estado .locking,
        // así la View no depende del preview en vivo (que ya detenemos abajo).
        state = .locking(frozenFrame: frame, confidence: confidence)
        stopCamera()
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        state = .analyzing(frame: frame)
        await runHeavyClassifier(on: frame)
    }

    private func runHeavyClassifier(on uiImage: UIImage) async {
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
            pile.volumenM3  = classification.volumenEstimadoM3
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

extension CapturaViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // [3] Copias locales capturadas ANTES de cualquier guard,
        //     para evitar data-race entre sessionQueue y MainActor.
        let isActive   = isScanningActive
        let epochAtStart = scanningEpoch

        guard isActive else { return }

        let now = Date()

        // [2] Watchdog: si llevamos > 3s esperando que el Task anterior libere
        //     el flag, asumimos que murió → reset forzado.
        if isAnalyzingFrame && now.timeIntervalSince(frameAnalysisStartedAt) > 3.0 {
            isAnalyzingFrame = false
            frameAnalysisStartedAt = .distantPast
        }

        // Throttle: ~2 fps
        guard now.timeIntervalSince(lastFrameAnalyzedAt) >= 0.5,
              !isAnalyzingFrame else { return }

        lastFrameAnalyzedAt = now
        // [2] Marcamos cuándo empezamos, para que el watchdog sepa cuánto llevamos.
        isAnalyzingFrame = true
        frameAnalysisStartedAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isAnalyzingFrame = false
            return
        }

        // [5] Usamos el CIContext estático — sin alloc por frame.
        let ciImage  = CIImage(cvPixelBuffer: pixelBuffer)
        let cgImage  = CapturaViewModel.ciContext.createCGImage(ciImage, from: ciImage.extent)
        let uiImage  = cgImage.map { UIImage(cgImage: $0, scale: 1.0, orientation: .right) }
        latestFrame  = uiImage

        Task { [weak self] in
            guard let self else { return }
            // [1] defer garantiza que isAnalyzingFrame se libera SIEMPRE:
            //     si la detección falla, si el Task se cancela, si hay un return temprano.
            defer { self.isAnalyzingFrame = false }

            let result = await ManureDetector.detect(in: pixelBuffer)
            await self.handleFrame(result: result, frame: uiImage, expectedEpoch: epochAtStart)
        }
    }

    private func handleFrame(
        result: DetectionResult,
        frame: UIImage?,
        expectedEpoch: Int
    ) async {
        // [3] Ya no revisamos isScanningActive aquí — epochAtStart es suficiente.
        //     Cada llamada a startCamera/stopCamera incrementa scanningEpoch,
        //     haciendo que los frames de epochs anteriores sean descartados.
        guard scanningEpoch == expectedEpoch,
              case .scanning = state else { return }

        lastDetection = result
        state = .scanning(lastDetection: result)

        let now = Date()
        let qualifies = result.boundingBox != nil
            && result.isLikelyManure
            && result.confidence >= 0.45

        if qualifies, let box = result.boundingBox {
            if let prevBox = stableBox, boxesAreClose(box, prevBox) {
                if let since = stableSince,
                   now.timeIntervalSince(since) >= 1.2,
                   let frame {
                    await lockOn(box: box, confidence: result.confidence, frame: frame)
                    return
                }
            } else {
                stableBox  = box
                stableSince = now
            }
        } else {
            stableBox  = nil
            stableSince = nil
        }
    }

    private nonisolated func boxesAreClose(_ a: CGRect, _ b: CGRect) -> Bool {
        let dx = a.midX - b.midX
        let dy = a.midY - b.midY
        return (dx * dx + dy * dy).squareRoot() < 0.15
    }
}
