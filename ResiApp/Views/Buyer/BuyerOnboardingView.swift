//
//  BuyerOnboardingView.swift
//  ResiApp
//
//  Created by Dev Jr.23 on 5/5/26.
//

import SwiftUI
import SwiftData
import CoreLocation
internal import MapKit

struct BuyerOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager

    var onComplete: () -> Void
    var onBack: () -> Void

    @State private var nombre: String = ""
    @State private var telefono: String = ""
    @State private var direccion: String = ""
    @State private var buscandoUbicacion = false
    @State private var ubicacionConfirmada = false
    @State private var latitudCapturada: Double = 0
    @State private var longitudCapturada: Double = 0
    @State private var errorUbicacion = false

    private var formularioCompleto: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty &&
        telefono.count >= 8 &&
        !direccion.trimmingCharacters(in: .whitespaces).isEmpty &&
        ubicacionConfirmada
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // MARK: - Header
                        VStack(spacing: 8) {
                            Image(systemName: "building.2.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.appBlue)
                                .padding(.bottom, 4)

                            Text("Perfil de Comprador")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("Ingresa los datos de tu planta")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                        // MARK: - Formulario
                        VStack(spacing: 0) {
                            campoTexto(icono: "building.2.fill", placeholder: "Nombre de la planta", texto: $nombre, teclado: .default)

                            Divider().padding(.leading, 52)

                            campoTexto(icono: "phone.fill", placeholder: "Teléfono", texto: $telefono, teclado: .phonePad)

                            Divider().padding(.leading, 52)

                            campoTexto(icono: "map.fill", placeholder: "Dirección (Ej. Celaya, GTO)", texto: $direccion, teclado: .default)

                            Divider().padding(.leading, 52)

                            // Botón de Ubicación
                            Button(action: capturarUbicacion) {
                                HStack(spacing: 16) {
                                    Image(systemName: ubicacionConfirmada ? "location.fill" : "location")
                                        .font(.system(size: 20))
                                        .foregroundStyle(ubicacionConfirmada ? Color.appBlue : Color.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ubicacionConfirmada ? "Ubicación capturada" : "Obtener mi ubicación")
                                            .font(.body)
                                            .foregroundStyle(ubicacionConfirmada ? Color.appBlue : .primary)

                                        if ubicacionConfirmada {
                                            Text(String(format: "%.4f, %.4f", latitudCapturada, longitudCapturada))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else if errorUbicacion {
                                            Text("No se pudo obtener. Activa el GPS.")
                                                .font(.caption)
                                                .foregroundStyle(Color.appRed)
                                        }
                                    }
                                    Spacer()

                                    if buscandoUbicacion {
                                        ProgressView()
                                    } else if ubicacionConfirmada {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.appBlue)
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(buscandoUbicacion)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)

                        // MARK: - Botón Confirmar
                        Button(action: crearPerfil) {
                            Text("Empezar como Comprador")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.appBlue)
                        .controlSize(.large)
                        .disabled(!formularioCompleto)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // MARK: - Custom Back Button
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Volver")
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(AnimatedBackButtonStyle())
                }
            }
            .onAppear {
                if locationManager.authorizationStatus == .authorizedWhenInUse ||
                   locationManager.authorizationStatus == .authorizedAlways {
                    capturarUbicacion()
                }
            }
        }
    }

    // MARK: - Componentes

    @ViewBuilder
    private func campoTexto(icono: String, placeholder: String, texto: Binding<String>, teclado: UIKeyboardType) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icono)
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            TextField(placeholder, text: texto)
                .font(.body)
                .keyboardType(teclado)
                .autocorrectionDisabled()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    // MARK: - Lógica

    private func capturarUbicacion() {
        buscandoUbicacion = true
        errorUbicacion = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let coord = locationManager.region.center
            latitudCapturada  = coord.latitude
            longitudCapturada = coord.longitude
            ubicacionConfirmada = true
            buscandoUbicacion = false

            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                if let place = placemarks?.first {
                    var partes: [String] = []
                    if let calle  = place.thoroughfare    { partes.append(calle) }
                    if let num    = place.subThoroughfare { partes.append(num) }
                    if let ciudad = place.locality        { partes.append(ciudad) }

                    if !partes.isEmpty && self.direccion.isEmpty {
                        self.direccion = partes.joined(separator: ", ")
                    }
                }
            }
        }
    }

    private func crearPerfil() {
        let perfil = BuyerProfile(
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            telefono: telefono.trimmingCharacters(in: .whitespaces),
            direccion: direccion.trimmingCharacters(in: .whitespaces),
            latitud: latitudCapturada,
            longitud: longitudCapturada
        )
        modelContext.insert(perfil)
        try? modelContext.save()
        onComplete()
    }
}

#Preview {
    BuyerOnboardingView(
        onComplete: { },
        onBack: { }
    )
}
