//
//  PerfilProductorView.swift
//  ResiApp
//
//  Historial conectado a ManurePile reales via @Query.
//  Stats y lista de lotes ya no dependen de SimulatedCapture.
//

import SwiftUI
import SwiftData
import PhotosUI
internal import MapKit

struct PerfilProductorView: View {
    @AppStorage("userRole") private var userRole: String = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationManager.self) private var locationManager

    @Query private var perfiles: [ProducerProfile]

    // Todos los lotes que ya salieron de pendingAnalysis (available o matched)
    @Query(
        filter: #Predicate<ManurePile> { $0.syncStatusRaw != "pendingAnalysis" },
        sort: \ManurePile.fecha,
        order: .reverse
    )
    private var historial: [ManurePile]

    @State private var mostrarConfirmacionRol = false
    @State private var mostrarReporte = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var aparecer = false

    private var perfil: ProducerProfile? { perfiles.first }

    // DateFormatter en español para mostrar "5 mayo 2026"
    private let fechaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if let perfil {
                VStack(spacing: 0) {
                    headerCompacto(perfil)
                    statsRow
                    accionesRow
                    lotesList
                    Spacer(minLength: 0)
                    botonCambiarRol
                }
            } else {
                ProgressView("Cargando perfil…")
            }
        }
        .onAppear { withAnimation(AppAnimation.easeSnap) { aparecer = true } }
        .alert("¿Cambiar rol?", isPresented: $mostrarConfirmacionRol) {
            Button("Cancelar", role: .cancel) {}
            Button("Cambiar", role: .destructive) { userRole = "" }
        } message: {
            Text("Volverás a la pantalla de selección de rol.")
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await cargarFotoPerfil(newItem) }
        }
        .sheet(isPresented: $mostrarReporte) {
            if let perfil { ReporteProductorView(perfil: perfil) }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerCompacto(_ perfil: ProducerProfile) -> some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    avatarView(perfil).frame(width: 96, height: 96)
                    ZStack {
                        Circle().fill(Color.appGreen).frame(width: 28, height: 28)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 3))
                    .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(perfil.nombre)
                    .font(.title3.weight(.semibold))
                Text(perfil.telefono)
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.top, 24).padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .opacity(aparecer ? 1 : 0)
        .offset(y: aparecer ? 0 : -10)
    }

    @ViewBuilder
    private func avatarView(_ perfil: ProducerProfile) -> some View {
        Group {
            if let data = perfil.fotoPerfilData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(LinearGradient(
                        colors: [Color(red: 1, green: 0.87, blue: 0.2),
                                 Color(red: 0.95, green: 0.7, blue: 0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("🍌").font(.system(size: 44))
                }
            }
        }
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
    }

    // MARK: - Stats (ahora desde historial de ManurePile)

    private var statsRow: some View {
        let total = historial.reduce(0.0) { $0 + $1.volumenM3 }
        let dias = perfil.map { diasRegistrado($0) } ?? "1"

        return HStack(spacing: 10) {
            statCard(valor: "\(historial.count)", label: "Lotes",    color: .appGreen)
            statCard(valor: String(format: "%.0f", total),           label: "m³ total", color: .blue)
            statCard(valor: dias,                                    label: "Días",     color: .orange)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func statCard(valor: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(valor).font(.title2.weight(.bold)).foregroundStyle(color).monospacedDigit()
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(0.5)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Acciones

    private var accionesRow: some View {
        HStack(spacing: 10) {
            // El botón de reporte (el de simularCaptura se retiró al conectar datos reales)
            Button(action: { mostrarReporte = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.richtext.fill")
                    Text("Ver reporte PDF").font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Color.appGreen.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.appGreen)
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }

    // MARK: - Lista de lotes (ManurePile)

    private var lotesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Mis lotes registrados")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    .textCase(.uppercase).tracking(0.5)
                Spacer()
                if !historial.isEmpty {
                    Text("\(historial.count)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 8)

            if historial.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(historial.enumerated()), id: \.element.id) { idx, pile in
                            loteRow(pile)
                            if idx < historial.count - 1 {
                                Divider().padding(.leading, 76)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 38, weight: .light)).foregroundStyle(.tertiary)
            Text("Aún no has registrado ningún lote")
                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Text("Escanea una pila con la pestaña Captura y publícala")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 16)
    }

    @ViewBuilder
    private func loteRow(_ pile: ManurePile) -> some View {
        HStack(spacing: 12) {
            // Icono izquierdo
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appGreen.opacity(0.12)).frame(width: 44, height: 44)
                Text("🐄").font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(fechaFormatter.string(from: pile.fecha))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(String(format: "%.1f m³", pile.volumenM3))
                    Text("·")
                    Text(String(format: "%.0f%% hum.", pile.humedadPct))
                }
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }

            Spacer()

            // Badge de estado
            statusBadge(pile.syncStatus)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    @ViewBuilder
    private func statusBadge(_ status: SyncStatus) -> some View {
        let (color, texto): (Color, String) = switch status {
        case .available: (.appGreen, "En marketplace")
        case .matched:   (.orange,   "Vendido")
        default:         (.gray,     "Pendiente")
        }

        Text(texto)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    // MARK: - Cambiar rol

    private var botonCambiarRol: some View {
        Button(role: .destructive) { mostrarConfirmacionRol = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                Text("Cambiar rol").font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.appRed).frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    // MARK: - Lógica

    private func diasRegistrado(_ perfil: ProducerProfile) -> String {
        let d = Calendar.current.dateComponents([.day], from: perfil.fechaRegistro, to: .now).day ?? 0
        return "\(max(1, d))"
    }

    private func cargarFotoPerfil(_ item: PhotosPickerItem?) async {
        guard let item, let perfil else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        if let jpg = UIImage(data: data)?.jpegData(compressionQuality: 0.8) {
            perfil.fotoPerfilData = jpg
            try? modelContext.save()
        }
    }
}
