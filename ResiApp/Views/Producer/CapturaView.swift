//
//  CapturaView.swift
//  ResiApp
//
//  Pestaña del productor — versión "smart capture" estilo Google Lens:
//
//  - Visor en vivo (AVCaptureSession) que detecta la pila automáticamente.
//  - Overlay 3D animado encima del objeto detectado.
//  - Lock-on automático cuando la detección es estable → análisis de IA.
//  - Rama paralela "Elegir de galería" que salta directo al análisis.
//  - Pantalla final con diagnóstico y botón de publicar al marketplace.
//

import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation
internal import MapKit

struct CapturaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager

    @State private var viewModel: CapturaViewModel?
    @State private var isShowingGallery = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let viewModel {
                content(vm: viewModel)
            } else {
                ProgressView().tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel == nil {
                viewModel = CapturaViewModel(
                    context: modelContext,
                    classifier: AppleIntelligenceClassifier(),
                    locationProvider: { [locationManager] in
                        locationManager.region.center
                    }
                )
            }
            if let vm = viewModel, case .requestingPermission = vm.state {
                await vm.requestCameraPermission()
            }
        }
        .onDisappear {
            viewModel?.stopCamera()
        }
        .sheet(isPresented: $isShowingGallery) {
            GalleryPicker { image in
                viewModel?.analyzeFromGallery(uiImage: image)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Content por estado

    @ViewBuilder
    private func content(vm: CapturaViewModel) -> some View {
        switch vm.state {

        case .requestingPermission:
            permissionLoader

        case .denied:
            CameraPermissionDeniedView {
                isShowingGallery = true
            }

        case .scanning(let detection):
            scanningContent(vm: vm, detection: detection)

        case .locking(_, let confidence):
            lockingContent(vm: vm, confidence: confidence)

        case .analyzing(let frame):
            analyzingContent(frame: frame)

        case .result(let classification, let frame):
            ResultadoScreen(
                resultado: classification,
                frame: frame,
                onPublicar: { vm.publicarEnMarketplace() },
                onReintentar: { vm.resetToScanning() }
            )

        case .error(let message, let frame):
            errorContent(message: message, frame: frame, vm: vm)
        }
    }

    // MARK: - Estado: scanning (cámara en vivo + recuadro estático)

    @ViewBuilder
    private func scanningContent(vm: CapturaViewModel, detection: DetectionResult) -> some View {
        ZStack {
            CameraPreviewView(session: vm.cameraSession)
                .ignoresSafeArea()

            // Recuadro estático estilo Tlane, centrado.
            SmartBoundingBoxOverlay(isLocked: false)

            VStack {
                topHint(detection: detection)
                Spacer()
                bottomBar
            }
        }
    }

    private func topHint(detection: DetectionResult) -> some View {
        let text: String
        if detection.isLikelyManure && detection.confidence >= 0.45 {
            text = "Mantén estable…"
        } else {
            text = "Centra la pila en el recuadro"
        }
        return Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 60)
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            // Galería (rama secundaria)
            Button {
                isShowingGallery = true
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundStyle(.white)
            }

            Spacer()

            // Atajo manual: si el detector no está disparando, el usuario
            // puede forzar un análisis con el frame actual. La detección
            // automática es lo principal, pero no atrapamos al usuario.
            Button {
                viewModel?.captureManually()
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 4).padding(-6))
            }

            Spacer()

            // Placeholder para mantener simétrico el shutter
            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
    }

    // MARK: - Estado: locking (recuadro sólido ~450ms)

    private func lockingContent(vm: CapturaViewModel, confidence: Double) -> some View {
        ZStack {
            CameraPreviewView(session: vm.cameraSession)
                .ignoresSafeArea()

            SmartBoundingBoxOverlay(isLocked: true)

            VStack {
                Text("Pila identificada")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 60)
                Spacer()
            }
        }
    }

    // MARK: - Estado: analyzing (frame congelado + spinner)

    private func analyzingContent(frame: UIImage) -> some View {
        ZStack {
            Image(uiImage: frame)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Capa oscura encima
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Analizando con IA…")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Estimando humedad, volumen y calidad")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Estado: error

    private func errorContent(message: String, frame: UIImage?, vm: CapturaViewModel) -> some View {
        ZStack {
            if let frame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color.black.opacity(0.6).ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                Text("No se pudo analizar")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    vm.resetToScanning()
                } label: {
                    Label("Intentar de nuevo", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.tlaneGreen)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Estado: solicitando permiso

    private var permissionLoader: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("Solicitando acceso a la cámara…")
                .foregroundStyle(.white)
                .font(.subheadline)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Pantalla de "permiso denegado"

private struct CameraPermissionDeniedView: View {
    let onUseGallery: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 54))
                .foregroundStyle(.white)
            Text("Necesitamos acceso a la cámara")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("ResiApp usa la cámara para identificar pilas de estiércol y analizarlas con IA. También puedes elegir una foto de tu galería.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Abrir Ajustes", systemImage: "gear")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.tlaneGreen)

                Button {
                    onUseGallery()
                } label: {
                    Label("Elegir de galería", systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
    }
}

// MARK: - Pantalla de resultado

private struct ResultadoScreen: View {
    let resultado: ManureClassification
    let frame: UIImage
    let onPublicar: () -> Void
    let onReintentar: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.top, 24)

                ResultadoCard(
                    resultado: resultado,
                    onPublicar: onPublicar,
                    onReintentar: onReintentar
                )
                .padding(.horizontal)

                Spacer(minLength: 32)
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Card de resultado (mismo diseño que la versión anterior)

private struct ResultadoCard: View {
    let resultado: ManureClassification
    let onPublicar: () -> Void
    let onReintentar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: resultado.esApto ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(resultado.esApto ? Color.tlaneGreen : .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resultado.esApto ? "Material apto" : "No procesable")
                        .font(.headline)
                    Text("Calidad: \(resultado.calidadLabel.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 24) {
                metricaView(
                    icono: "drop.fill",
                    color: .blue,
                    valor: String(format: "%.0f%%", resultado.humedadPct),
                    label: "Humedad"
                )
                metricaView(
                    icono: "cube.fill",
                    color: .orange,
                    valor: String(format: "%.1f m³", resultado.volumenEstimadoM3),
                    label: "Volumen"
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Análisis")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(resultado.razon)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if resultado.esApto {
                Button(action: onPublicar) {
                    Label("Publicar en marketplace", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.tlaneGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            Button(action: onReintentar) {
                Label("Tomar otra foto", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func metricaView(icono: String, color: Color, valor: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icono)
                .foregroundStyle(color)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(valor).font(.title3.bold())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
