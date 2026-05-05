//
//  PerfilCompradorView.swift
//  ResiApp
//
//  Created by Dev Jr.23 on 5/5/26.
//

import SwiftUI
import SwiftData
import PhotosUI
internal import MapKit

struct PerfilCompradorView: View {
    @AppStorage("userRole") private var userRole: String = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var perfiles: [BuyerProfile]
    @Query private var matches: [Match]

    @State private var mostrarConfirmacionRol = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var aparecer = false

    // Estados para animaciones de botones
    @State private var presionandoCambiarRol = false
    @State private var presionandoAvatar = false

    private var perfil: BuyerProfile? { perfiles.first }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if let perfil {
                VStack(spacing: 0) {
                    barraSuperior
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            headerCompacto(perfil)
                            statsRow
                            miniMapa(perfil)
                            matchesList
                            botonCambiarRol
                                .padding(.top, 20)
                                .padding(.bottom, 30)
                        }
                    }
                }
            } else {
                ProgressView("Cargando perfil…")
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { aparecer = true } }
        .alert("¿Cambiar rol?", isPresented: $mostrarConfirmacionRol) {
            Button("Cancelar", role: .cancel) {}
            Button("Cambiar", role: .destructive) { userRole = "" }
        } message: {
            Text("Volverás a la pantalla de selección de rol.")
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await cargarFotoPerfil(newItem) }
        }
    }

    // MARK: - Barra superior

    private var barraSuperior: some View {
        HStack {
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Header compacto

    @ViewBuilder
    private func headerCompacto(_ perfil: BuyerProfile) -> some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    avatarView(perfil).frame(width: 96, height: 96)
                    ZStack {
                        Circle().fill(Color.appBlue).frame(width: 28, height: 28)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 3))
                    .offset(x: 2, y: 2)
                }
                .scaleEffect(presionandoAvatar ? 0.96 : 1)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeInOut(duration: 0.15)) { presionandoAvatar = true }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { presionandoAvatar = false }
                    }
            )

            VStack(spacing: 2) {
                Text(perfil.nombre)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(perfil.telefono)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .opacity(aparecer ? 1 : 0)
        .offset(y: aparecer ? 0 : -10)
    }

    @ViewBuilder
    private func avatarView(_ perfil: BuyerProfile) -> some View {
        Group {
            if let data = perfil.fotoPerfilData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(LinearGradient(
                        colors: [Color(red: 0.35, green: 0.6, blue: 0.95),
                                 Color(red: 0.2, green: 0.45, blue: 0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("🏭").font(.system(size: 44))
                }
            }
        }
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(valor: "\(matches.count)", label: "Matches", color: .appBlue)
            statCard(
                valor: "\(matches.filter { $0.estado == .confirmado }.count)",
                label: "Confirmados",
                color: .appGreen
            )
            statCard(
                valor: "\(matches.filter { $0.estado == .propuesto }.count)",
                label: "Pendientes",
                color: .orange
            )
        }
        .padding(.horizontal, 16)
        .opacity(aparecer ? 1 : 0)
        .offset(y: aparecer ? 0 : 8)
    }

    @ViewBuilder
    private func statCard(valor: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(valor)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - Mini mapa

    @ViewBuilder
    private func miniMapa(_ perfil: BuyerProfile) -> some View {
        let coord = CLLocationCoordinate2D(latitude: perfil.latitud, longitude: perfil.longitud)
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ubicación de planta")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 8)

            ZStack(alignment: .bottomLeading) {
                Map(coordinateRegion: .constant(region),
                    annotationItems: [BuyerMapPinSimple(coordinate: coord)]) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: .appBlue)
                }
                .frame(height: 150)
                .allowsHitTesting(false)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appBlue)
                    Text(perfil.direccion)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Matches list

    private var matchesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Actividad reciente")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if !matches.isEmpty {
                    Text("\(matches.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 8)

            if matches.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.element.id) { idx, match in
                        matchRow(match)
                        if idx < matches.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .padding(.horizontal, 16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Sin actividad")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Tus matches aparecerán aquí cuando conectes con un productor")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func matchRow(_ match: Match) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(colorEstado(match.estado).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: iconoEstado(match.estado))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(colorEstado(match.estado))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Match registrado")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(match.estado.rawValue.capitalized)
                    Text("·")
                    Text(match.fecha, format: .dateTime.day().month(.abbreviated))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(match.fecha, format: .relative(presentation: .numeric))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func iconoEstado(_ estado: MatchEstado) -> String {
        switch estado {
        case .propuesto:  return "clock.fill"
        case .confirmado: return "checkmark.circle.fill"
        case .rechazado:  return "xmark.circle.fill"
        }
    }

    private func colorEstado(_ estado: MatchEstado) -> Color {
        switch estado {
        case .propuesto:  return .orange
        case .confirmado: return .appGreen
        case .rechazado:  return .appRed
        }
    }

    // MARK: - Cambiar rol

    private var botonCambiarRol: some View {
        Button(role: .destructive) {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            mostrarConfirmacionRol = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                Text("Cambiar rol")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.appRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 16)
    }

    // MARK: - Foto

    private func cargarFotoPerfil(_ item: PhotosPickerItem?) async {
        guard let item, let perfil else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        if let jpg = UIImage(data: data)?.jpegData(compressionQuality: 0.8) {
            await MainActor.run {
                perfil.fotoPerfilData = jpg
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Estilo de botón con animación de escala (HIG-friendly)

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct BuyerMapPinSimple: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
