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

    // Estados para el mock-up de búsqueda de match (MVP — animación determinista)
    @State private var buscandoMatch = false
    @State private var matchEncontrado = false
    @State private var pulsoActivo = false

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

                            // Botón de búsqueda de match — solo si no hay matches activos
                            // (todos rechazados también cuenta como "puedes buscar otro").
                            if matches.isEmpty || matches.allSatisfy({ $0.estado == .rechazado }) {
                                botonBuscarMatch
                            }

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

            // Animación: cuando matches.count cambia (típicamente 0 → 1 al insertar
            // el Match mock), la transición entre emptyState y la lista es suave.
            Group {
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
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: matches.count)
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

    // MARK: - Buscar match (mock-up animado para MVP)
    //
    // Esta sección es UI/UX puro — no hay lógica real de matching todavía.
    // El botón dispara una secuencia determinista de 4s que termina insertando
    // un Match mock en SwiftData para demostrar el flow.

    @ViewBuilder
    private var botonBuscarMatch: some View {
        Group {
            if matchEncontrado {
                // Estado 3: tarjeta de "match encontrado"
                tarjetaMatchEncontrado
                    .transition(.scale.combined(with: .opacity))
            } else if buscandoMatch {
                // Estado 2: pulsos animados
                vistaBuscando
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Estado 1: botón en reposo
                Button {
                    iniciarBusquedaMock()
                } label: {
                    Label("Buscar match disponible", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appGreen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }

    /// Estado 2: tres círculos concéntricos pulsando + texto
    private var vistaBuscando: some View {
        VStack(spacing: 12) {
            ZStack {
                // Tres anillos con opacidad decreciente. El scaleEffect oscila
                // gracias al toggle de pulsoActivo + .repeatForever.
                Circle()
                    .fill(Color.appGreen.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulsoActivo ? 1.0 : 0.7)
                Circle()
                    .fill(Color.appGreen.opacity(0.15))
                    .frame(width: 76, height: 76)
                    .scaleEffect(pulsoActivo ? 1.0 : 0.7)
                Circle()
                    .fill(Color.appGreen.opacity(0.25))
                    .frame(width: 52, height: 52)
                    .scaleEffect(pulsoActivo ? 1.0 : 0.7)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.appGreen)
            }
            .frame(height: 110)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: pulsoActivo
            )

            Text("Buscando productores cercanos…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    /// Estado 3: tarjeta verde de "¡Match encontrado!"
    private var tarjetaMatchEncontrado: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.appGreen)

            VStack(alignment: .leading, spacing: 3) {
                Text("¡Match encontrado!")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Planta Biogás Puebla")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text("12.4 km")
                        .font(.caption.monospacedDigit())
                }
                .foregroundStyle(Color.appGreen)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.appGreen.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.appGreen.opacity(0.4), lineWidth: 1)
        )
    }

    private func iniciarBusquedaMock() {
        guard perfil != nil else { return }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        withAnimation(.easeInOut(duration: 0.3)) { buscandoMatch = true }
        // Disparar el toggle dentro de withAnimation para que .repeatForever
        // tome efecto en el scaleEffect de los anillos.
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulsoActivo = true
        }

        // Después de 2.8s simulamos que encontró un match
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                matchEncontrado = true
            }

            // 1.2s más → insertar Match real en SwiftData y resetear estados
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                let nuevoMatch = Match(
                    pileId: UUID(),       // mock — en prod vendría del ManurePile real
                    plantId: UUID(),      // mock — en prod vendría de ProcessingPlant
                    estado: .propuesto,
                    distanciaKm: 12.4
                )
                modelContext.insert(nuevoMatch)
                try? modelContext.save()

                withAnimation(.easeOut(duration: 0.4)) {
                    buscandoMatch = false
                    matchEncontrado = false
                    pulsoActivo = false
                }
            }
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
