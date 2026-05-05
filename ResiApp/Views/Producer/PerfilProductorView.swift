//
//  PerfilProductorView.swift
//  ResiApp
//
//  Created by Dev Jr.23 on 5/5/26.
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
    @State private var mostrarConfirmacionRol = false
    @State private var simulandoCaptura = false
    @State private var mostrarExito = false
    @State private var mostrarReporte = false          // ← NUEVO
    @State private var pickerItem: PhotosPickerItem?
    @State private var aparecer = false

    private var perfil: ProducerProfile? { perfiles.first }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if let perfil {
                VStack(spacing: 0) {
                    headerCompacto(perfil)
                    statsRow(perfil)
                    accionesRow                        // ← ahora incluye botón de reporte
                    publicacionesList(perfil)
                    Spacer(minLength: 0)
                    botonCambiarRol
                }
            } else {
                ProgressView("Cargando perfil…")
            }

            // Toast éxito captura
            if mostrarExito {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.appGreen)
                        Text("Captura publicada")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
        // ← NUEVO: sheet de reportes
        .sheet(isPresented: $mostrarReporte) {
            if let perfil {
                ReporteProductorView(perfil: perfil)
            }
        }
    }

    // MARK: - Header compacto

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
                    .foregroundStyle(.primary)

                Text(perfil.telefono)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
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

    // MARK: - Stats row

    @ViewBuilder
    private func statsRow(_ perfil: ProducerProfile) -> some View {
        let capturas = capturasDePerfil(perfil)
        HStack(spacing: 10) {
            statCard(valor: "\(capturas.count)", label: "Capturas", color: .appGreen)
            statCard(valor: String(format: "%.0f", volumenTotal(perfil)), label: "m³ total", color: .blue)
            statCard(valor: diasRegistrado(perfil), label: "Días", color: .orange)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func statCard(valor: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(valor)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Acciones ← MODIFICADO: ahora son dos botones en HStack

    private var accionesRow: some View {
        HStack(spacing: 10) {
            // Botón principal: simular captura
            Button(action: simularCaptura) {
                HStack(spacing: 8) {
                    if simulandoCaptura {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(simulandoCaptura ? "Procesando…" : "Simular captura")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.appGreen,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(simulandoCaptura)

            // Botón secundario: generar reporte PDF
            Button(action: { mostrarReporte = true }) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(
                        Color.appGreen.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundStyle(.appGreen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Publicaciones

    @ViewBuilder
    private func publicacionesList(_ perfil: ProducerProfile) -> some View {
        let capturas = capturasDePerfil(perfil)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Publicaciones")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if !capturas.isEmpty {
                    Text("\(capturas.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 8)

            if capturas.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(capturas.enumerated()), id: \.element.id) { idx, captura in
                            capturaRow(captura)
                            if idx < capturas.count - 1 {
                                Divider().padding(.leading, 76)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Sin publicaciones")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Toca \"Simular captura\" para empezar")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func capturaRow(_ captura: SimulatedCapture) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appGreen.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(emojiAnimal(captura.animal)).font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(captura.animal)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(String(format: "%.0f m³", captura.volumenM3))
                    Text("·")
                    Text(String(format: "%.0f%% hum.", captura.humedadPct))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Spacer()

            Text(captura.fecha, format: .relative(presentation: .numeric))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Cambiar rol

    private var botonCambiarRol: some View {
        Button(role: .destructive) {
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
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Lógica

    private func capturasDePerfil(_ perfil: ProducerProfile) -> [SimulatedCapture] {
        let id = perfil.id
        let desc = FetchDescriptor<SimulatedCapture>(
            predicate: #Predicate { $0.producerProfileId == id },
            sortBy: [SortDescriptor(\.fecha, order: .reverse)]
        )
        return (try? modelContext.fetch(desc)) ?? []
    }

    private func volumenTotal(_ perfil: ProducerProfile) -> Double {
        capturasDePerfil(perfil).reduce(0) { $0 + $1.volumenM3 }
    }

    private func diasRegistrado(_ perfil: ProducerProfile) -> String {
        let d = Calendar.current.dateComponents([.day], from: perfil.fechaRegistro, to: .now).day ?? 0
        return "\(max(1, d))"
    }

    private func simularCaptura() {
        guard let perfil else { return }
        simulandoCaptura = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let coord = locationManager.region.center
            let cap = SimulatedCapture.aleatorio(profileId: perfil.id, lat: coord.latitude, lon: coord.longitude)
            modelContext.insert(cap)
            try? modelContext.save()
            simulandoCaptura = false
            withAnimation(AppAnimation.spring) { mostrarExito = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { mostrarExito = false }
            }
        }
    }

    private func cargarFotoPerfil(_ item: PhotosPickerItem?) async {
        guard let item, let perfil else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        if let jpg = UIImage(data: data)?.jpegData(compressionQuality: 0.8) {
            perfil.fotoPerfilData = jpg
            try? modelContext.save()
        }
    }

    private func emojiAnimal(_ raw: String) -> String {
        if raw.contains("Bovino")  { return "🐄" }
        if raw.contains("Porcino") { return "🐷" }
        if raw.contains("Aviar")   { return "🐔" }
        if raw.contains("Equino")  { return "🐴" }
        if raw.contains("Ovino")   { return "🐑" }
        return "🐾"
    }
}
