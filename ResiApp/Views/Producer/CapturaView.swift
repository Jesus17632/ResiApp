//
//  CapturaView.swift
//  ResiApp
//
//  Pestaña del productor: tomar/seleccionar foto, analizarla con
//  Apple Intelligence (Vision + Foundation Models), y publicarla
//  al marketplace si el material es apto.
//

import SwiftUI
import SwiftData
import PhotosUI
internal import MapKit

struct CapturaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager

    // Servicio de clasificación. Si quieres swap (Gemini, CoreML, etc.)
    // basta cambiar esta línea — todo el resto usa el protocolo.
    private let classifier: any ManureClassifierService = AppleIntelligenceClassifier()

    // Estado de la foto y del análisis
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var savedFileName: String?

    // Estado para presentar la cámara
    @State private var isShowingCamera = false

    @State private var isProcesando = false
    @State private var resultado: ManureClassification?
    @State private var pileEnAnalisis: ManurePile?

    // Manejo de errores y avisos
    @State private var modelUnavailableMessage: String?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showNotApto = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Preview de foto o placeholder
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                    } else {
                        placeholder
                    }

                    // 2. Banners
                    if locationManager.authorizationStatus == .denied ||
                       locationManager.authorizationStatus == .restricted {
                        bannerSinUbicacion
                    }
                    if let modelUnavailableMessage {
                        bannerModeloNoDisponible(mensaje: modelUnavailableMessage)
                    }

                    // 3. Si ya hay resultado, mostrar card de resultados.
                    //    Si no, mostrar los botones de acción.
                    if let resultado {
                        ResultadoCard(
                            resultado: resultado,
                            onPublicar: { publicarEnMarketplace(resultado) },
                            onReintentar: { reset() }
                        )
                        .padding(.horizontal)
                    } else {
                        botonesAccion
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle("Captura")
            .onChange(of: selectedItem) { _, newValue in
                Task { await cargarImagenDesdePicker(newValue) }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { uiImage in
                    handleCameraImage(uiImage)
                }
                .ignoresSafeArea()
            }
            .alert("Material no procesable", isPresented: $showNotApto) {
                Button("Tomar otra foto") { reset() }
            } message: {
                Text(resultado?.razon ?? "El material detectado no es apto para procesamiento.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Algo salió mal.")
            }
        }
    }

    // MARK: - Subvistas

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Toma una foto de la pila de estiércol")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var bannerSinUbicacion: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.orange)
            Text("Sin permiso de ubicación. La pila se guardará sin coordenadas exactas.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private func bannerModeloNoDisponible(mensaje: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Intelligence")
                    .font(.caption.bold())
                Text(mensaje)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private var botonesAccion: some View {
        VStack(spacing: 12) {
            // Botón principal: tomar foto con la cámara
            Button {
                isShowingCamera = true
            } label: {
                Label(
                    imageData == nil ? "Tomar foto" : "Tomar otra foto",
                    systemImage: "camera.fill"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.tlaneGreen)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Botón secundario: seleccionar de la galería
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    "Elegir de galería",
                    systemImage: "photo.on.rectangle.angled"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Analizar con Apple Intelligence
            Button {
                Task { await analizarConIA() }
            } label: {
                HStack(spacing: 8) {
                    if isProcesando {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isProcesando ? "Analizando con IA…" : "Analizar con IA")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(imageData == nil ? Color.gray.opacity(0.4) : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(imageData == nil || isProcesando)
        }
        .padding(.horizontal)
    }

    // MARK: - Lógica: cargar foto desde el picker (galería)

    private func cargarImagenDesdePicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            print("❌ No se pudo cargar la imagen del picker")
            return
        }
        await MainActor.run {
            persistirImagen(data: data)
        }
    }

    // MARK: - Lógica: cargar foto desde la cámara

    private func handleCameraImage(_ uiImage: UIImage) {
        // Convertimos a JPEG con compresión razonable. Mismo formato que el picker.
        guard let data = uiImage.jpegData(compressionQuality: 0.85) else {
            print("❌ No se pudo convertir la imagen de la cámara a JPEG")
            errorMessage = "No se pudo procesar la foto tomada."
            showError = true
            return
        }
        persistirImagen(data: data)
    }

    /// Guarda los bytes de la foto en Documents/ y actualiza el estado de la vista.
    /// Se usa tanto desde la cámara como desde la galería.
    private func persistirImagen(data: Data) {
        imageData = data
        resultado = nil   // si había resultado anterior, lo limpiamos

        let fileName = "pile_\(UUID().uuidString).jpg"
        guard let url = documentsURL()?.appendingPathComponent(fileName) else {
            savedFileName = nil
            return
        }

        do {
            try data.write(to: url)
            savedFileName = fileName
            print("📸 Foto guardada en Documents/: \(fileName)")
        } catch {
            print("❌ Error guardando foto: \(error)")
            savedFileName = nil
        }
    }

    // MARK: - Lógica: analizar con IA

    private func analizarConIA() async {
        guard let imageData, let savedFileName else { return }

        isProcesando = true
        modelUnavailableMessage = nil

        let coord = locationManager.region.center

        // 1. Crear pile preliminar con .pendingAnalysis
        let pile = ManurePile(
            fecha: .now,
            volumenM3: 0,
            humedadPct: 0,
            latitud: coord.latitude,
            longitud: coord.longitude,
            fotoFileName: savedFileName,
            audioTranscripcion: nil,
            syncStatus: .pendingAnalysis
        )
        modelContext.insert(pile)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "No se pudo guardar la pila: \(error.localizedDescription)"
            showError = true
            isProcesando = false
            return
        }
        pileEnAnalisis = pile

        // 2. Clasificar
        do {
            let classification = try await classifier.classify(imageData: imageData)
            print("🧠 Clasificación: humedad=\(classification.humedadPct)%, vol=\(classification.volumenEstimadoM3)m³, apto=\(classification.esApto)")

            // 3. Actualizar pile con los valores reales
            pile.humedadPct = classification.humedadPct
            pile.volumenM3 = classification.volumenEstimadoM3
            // Nota: NO marcamos .available aquí. El productor decide
            // explícitamente publicarla con el botón "Publicar en marketplace".
            try? modelContext.save()

            resultado = classification

            // Si no es apto, mostramos alert y no permitimos publicar.
            if !classification.esApto {
                showNotApto = true
            }

        } catch let error as ClassifierError {
            switch error {
            case .modelUnavailable(let reason):
                // El pile queda en .pendingAnalysis: se podrá reintentar después.
                modelUnavailableMessage = reason
            default:
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcesando = false
    }

    // MARK: - Lógica: publicar al marketplace

    private func publicarEnMarketplace(_ classification: ManureClassification) {
        guard classification.esApto, let pile = pileEnAnalisis else { return }
        pile.syncStatus = .available
        do {
            try modelContext.save()
            print("✅ Pila publicada en marketplace. id=\(pile.id)")
            reset()
        } catch {
            errorMessage = "No se pudo publicar: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Reset / utilidades

    private func reset() {
        selectedItem = nil
        imageData = nil
        savedFileName = nil
        resultado = nil
        pileEnAnalisis = nil
        modelUnavailableMessage = nil
    }

    private func documentsURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}

// MARK: - Card de resultado (subvista)

private struct ResultadoCard: View {
    let resultado: ManureClassification
    let onPublicar: () -> Void
    let onReintentar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
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

            // Métricas
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

            // Razón del modelo
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

            // Acciones
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
