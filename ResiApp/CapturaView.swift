//
//  CapturaView.swift
//  EcoVinculo
//
//  Pestaña del productor: tomar/seleccionar foto, guardarla localmente
//  en Documents, y crear un ManurePile preliminar con syncStatus =
//  .pendingAnalysis. Ahora también guarda la ubicación real del
//  productor leída desde LocationManager.
//
//  El botón "Analizar con IA" en este Bloque 1 solo guarda + imprime;
//  en Bloque 2 llamará a GeminiService.classifyManureImage(...).
//

import SwiftUI
import SwiftData
import PhotosUI
internal import MapKit

struct CapturaView: View {
    @Environment(\.modelContext) private var modelContext

    // LocationManager compartido. Lo inyecta EcoVinculoApp vía .environment(...).
    @Environment(LocationManager.self) private var locationManager

    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var savedFileName: String?
    @State private var isProcesando = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview de la foto o placeholder
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                    } else {
                        placeholder
                    }

                    // Banner de ubicación: avisa si todavía no hay permiso
                    if locationManager.authorizationStatus == .denied ||
                       locationManager.authorizationStatus == .restricted {
                        bannerSinUbicacion
                    }

                    // PhotosPicker SwiftUI nativo: incluye opción de cámara
                    // automáticamente en dispositivos físicos.
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            imageData == nil ? "Seleccionar foto" : "Cambiar foto",
                            systemImage: "photo.on.rectangle.angled"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Botón principal: deshabilitado mientras no haya foto.
                    Button(action: analizarConIA) {
                        HStack {
                            if isProcesando {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Analizar con IA")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(imageData == nil ? Color.gray.opacity(0.4) : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(imageData == nil || isProcesando)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle("Captura")
            .onChange(of: selectedItem) { _, newValue in
                Task { await cargarYGuardarImagen(newValue) }
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

    // MARK: - Lógica

    /// Carga los Data del PhotosPickerItem y los persiste en Documents.
    /// Solo guardamos el nombre de archivo en SwiftData, no la ruta absoluta.
    private func cargarYGuardarImagen(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            print("❌ No se pudo cargar la imagen del picker")
            return
        }

        imageData = data

        let fileName = "pile_\(UUID().uuidString).jpg"
        guard let url = documentsURL()?.appendingPathComponent(fileName) else { return }

        do {
            try data.write(to: url)
            savedFileName = fileName
            print("📸 Foto guardada en Documents/: \(fileName)")
        } catch {
            print("❌ Error guardando foto: \(error)")
            savedFileName = nil
        }
    }

    /// Crea el ManurePile preliminar y lo persiste con syncStatus = .pendingAnalysis.
    /// Ahora incluye coordenadas reales del LocationManager.
    private func analizarConIA() {
        guard let savedFileName else {
            print("⚠️ No hay foto guardada todavía")
            return
        }

        isProcesando = true

        // Coordenadas: leemos el centro actual del LocationManager.
        // Si todavía no hay fix de GPS, será el default (CDMX 19.4326, -99.1332),
        // lo cual es aceptable como fallback para el hackathon.
        let coord = locationManager.region.center

        let pile = ManurePile(
            fecha: .now,
            volumenM3: 0,        // Se llena en Bloque 2 con la respuesta de Gemini
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
            print("✅ ManurePile guardado. id=\(pile.id) coord=(\(coord.latitude), \(coord.longitude))")
            print("ℹ️ TODO Bloque 2: llamar a GeminiService.classifyManureImage(imageData:)")
        } catch {
            print("❌ Error persistiendo ManurePile: \(error)")
        }

        isProcesando = false
    }

    /// URL al directorio Documents del sandbox de la app.
    private func documentsURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}
