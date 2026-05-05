//
//  ReporteProductorView.swift
//  ResiApp
//
//  Genera un PDF con ImageRenderer (iOS 16+) y guarda el historial en SwiftData.
//

import SwiftUI
import SwiftData
internal import MapKit

// MARK: - Sheet principal

struct ReporteProductorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let perfil: ProducerProfile

    @Query(sort: \ReporteProductor.fechaGenerado, order: .reverse)
    private var todosLosReportes: [ReporteProductor]

    @State private var generando = false
    @State private var pdfURL: URL?
    @State private var mostrarShare = false
    @State private var mostrarToast = false

    // Filtrar solo los de este perfil
    private var historial: [ReporteProductor] {
        todosLosReportes.filter { $0.producerProfileId == perfil.id }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        resumenSection
                        botonGenerar
                        historialSection
                        Spacer(minLength: 60)
                    }
                    .padding(.top, 8)
                }

                // Toast flotante
                if mostrarToast {
                    toastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationTitle("Generar Reporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(.appGreen)
                }
            }
            .sheet(isPresented: $mostrarShare) {
                if let url = pdfURL {
                    ShareSheet(url: url)
                }
            }
        }
    }

    // MARK: - Resumen (preview de lo que irá en el PDF)

    private var resumenSection: some View {
        let stats = calcularStats()
        return VStack(alignment: .leading, spacing: 0) {
            encabezadoSeccion("Actividad · Últimos 30 días")

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    statTile(
                        valor: "\(stats.capturasUltimos30)",
                        label: "Capturas",
                        icono: "camera.fill",
                        color: .appGreen
                    )
                    statTile(
                        valor: String(format: "%.0f m³", stats.volumenUltimos30),
                        label: "Volumen",
                        icono: "cube.fill",
                        color: .blue
                    )
                }
                HStack(spacing: 10) {
                    statTile(
                        valor: "$\(Int(stats.ingresoEstimado).formatted())",
                        label: "Ingreso est.",
                        icono: "dollarsign.circle.fill",
                        color: Color(red: 0.13, green: 0.55, blue: 0.13)
                    )
                    statTile(
                        valor: "\(stats.matchesConfirmados)",
                        label: "Matches ✓",
                        icono: "link.circle.fill",
                        color: .orange
                    )
                }
                HStack(spacing: 10) {
                    statTile(
                        valor: "\(stats.diasActivo) días",
                        label: "Activo",
                        icono: "calendar",
                        color: .purple
                    )
                    statTile(
                        valor: String(format: "%.0f%%", stats.humedadPromedio),
                        label: "Hum. prom.",
                        icono: "drop.fill",
                        color: .cyan
                    )
                }

                // Animal top — ancho completo
                HStack(spacing: 14) {
                    Image(systemName: "hare.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.brown)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Animal más frecuente")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(stats.animalTop)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Text("\(stats.capturasAnimalTop) capturas")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Botón generar PDF

    private var botonGenerar: some View {
        Button {
            Task { await generarPDF() }
        } label: {
            HStack(spacing: 10) {
                if generando {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(generando ? "Generando PDF…" : "Generar PDF y guardar")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                generando ? Color.appGreen.opacity(0.55) : Color.appGreen,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
        }
        .disabled(generando)
        .padding(.horizontal, 16)
    }

    // MARK: - Historial de reportes generados

    private var historialSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            encabezadoSeccion("Historial guardado")

            if historial.isEmpty {
                estadoVacioHistorial
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(historial.enumerated()), id: \.element.id) { idx, r in
                        historialRow(r)
                        if idx < historial.count - 1 {
                            Divider().padding(.leading, 68)
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

    @ViewBuilder
    private func historialRow(_ r: ReporteProductor) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appGreen.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: "doc.fill")
                    .foregroundStyle(.appGreen)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.fechaGenerado, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 5) {
                    Text("\(r.capturasUltimos30) capturas")
                    Text("·")
                    Text(String(format: "%.0f m³", r.volumenTotalM3))
                    Text("·")
                    Text("$\(Int(r.ingresoEstimado).formatted())")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            if r.pdfData != nil {
                Button { compartir(r) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.appGreen)
                        .font(.system(size: 17))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var estadoVacioHistorial: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.clock")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Sin reportes guardados")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Genera tu primer PDF arriba")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.appGreen)
            Text("PDF guardado")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Compartir") { mostrarShare = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.appGreen)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - UI helpers

    private func encabezadoSeccion(_ texto: String) -> some View {
        Text(texto)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 10)
    }

    @ViewBuilder
    private func statTile(valor: String, label: String, icono: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(valor)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: - Lógica: calcular stats

    struct Stats {
        var totalCapturas: Int
        var capturasUltimos30: Int
        var volumenUltimos30: Double
        var diasActivo: Int
        var matchesConfirmados: Int
        var matchesPropuestos: Int
        var ingresoEstimado: Double
        var animalTop: String
        var capturasAnimalTop: Int
        var humedadPromedio: Double
        var capturasPorFecha: [(dia: String, volumen: Double)]
    }

    private func calcularStats() -> Stats {
        // Capturas del perfil
        let idPerfil = perfil.id
        let descCap = FetchDescriptor<SimulatedCapture>(
            predicate: #Predicate { $0.producerProfileId == idPerfil },
            sortBy: [SortDescriptor(\.fecha, order: .reverse)]
        )
        let todasCapturas = (try? modelContext.fetch(descCap)) ?? []

        let ahora = Date.now
        let hace30 = Calendar.current.date(byAdding: .day, value: -30, to: ahora)!
        let cap30 = todasCapturas.filter { $0.fecha >= hace30 }

        // Volumen últimos 30 días
        let vol30 = cap30.map(\.volumenM3).reduce(0, +)

        // Días activo
        let dias = max(1, Calendar.current.dateComponents([.day], from: perfil.fechaRegistro, to: ahora).day ?? 1)

        // Matches
        let descMatch = FetchDescriptor<Match>()
        let matches = (try? modelContext.fetch(descMatch)) ?? []
        let confirmados = matches.filter { $0.estado == .confirmado }.count
        let propuestos  = matches.filter { $0.estado == .propuesto  }.count

        // Ingreso estimado: ~$45 MXN por m³ (precio referencia mercado biogás MX)
        let ingreso = vol30 * 45.0

        // Animal top
        let freq = Dictionary(grouping: cap30, by: \.animal)
        let topEntry = freq.max(by: { $0.value.count < $1.value.count })
        let animalTop = topEntry?.key ?? "Sin capturas"
        let capAnimalTop = topEntry?.value.count ?? 0

        // Humedad promedio
        let humProm = cap30.isEmpty ? 0 : cap30.map(\.humedadPct).reduce(0, +) / Double(cap30.count)

        // Capturas por día (para el PDF — agrupadas)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        let porDia = Dictionary(grouping: cap30) { formatter.string(from: $0.fecha) }
        let porDiaOrdenado = porDia
            .map { (dia: $0.key, volumen: $0.value.map(\.volumenM3).reduce(0, +)) }
            .sorted { $0.dia < $1.dia }

        return Stats(
            totalCapturas: todasCapturas.count,
            capturasUltimos30: cap30.count,
            volumenUltimos30: vol30,
            diasActivo: dias,
            matchesConfirmados: confirmados,
            matchesPropuestos: propuestos,
            ingresoEstimado: ingreso,
            animalTop: animalTop,
            capturasAnimalTop: capAnimalTop,
            humedadPromedio: humProm,
            capturasPorFecha: porDiaOrdenado
        )
    }

    // MARK: - Generar PDF con ImageRenderer

    @MainActor
    private func generarPDF() async {
        generando = true
        let stats = calcularStats()

        // Capturas últimos 30 días para la tabla del PDF
        let idPerfil = perfil.id
        let hace30 = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let descCap = FetchDescriptor<SimulatedCapture>(
            predicate: #Predicate { $0.producerProfileId == idPerfil },
            sortBy: [SortDescriptor(\.fecha, order: .reverse)]
        )
        let cap30 = ((try? modelContext.fetch(descCap)) ?? []).filter { $0.fecha >= hace30 }

        // Construir la vista PDF
        let vistaA4 = PDFReporteView(perfil: perfil, stats: stats, capturas: cap30)

        // Renderizar con ImageRenderer
        let renderer = ImageRenderer(content: vistaA4)
        renderer.proposedSize = .init(width: 595, height: 842)

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("resiapp_temp.pdf")

        renderer.render { size, cgContext in
            var box = CGRect(origin: .zero, size: size)
            guard
                let consumer = CGDataConsumer(url: tempPath as CFURL),
                let pdfCtx = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }
            pdfCtx.beginPDFPage(nil)
            cgContext(pdfCtx)
            pdfCtx.endPDFPage()
            pdfCtx.closePDF()
        }

        let pdfData = try? Data(contentsOf: tempPath)

        // Persistir en SwiftData
        let reporte = ReporteProductor(
            producerProfileId: perfil.id,
            totalCapturas: stats.totalCapturas,
            volumenTotalM3: stats.volumenUltimos30,
            diasActivo: stats.diasActivo,
            capturasUltimos30: stats.capturasUltimos30,
            matchesConfirmados: stats.matchesConfirmados,
            matchesPropuestos: stats.matchesPropuestos,
            ingresoEstimado: stats.ingresoEstimado,
            animalMasFrecuente: stats.animalTop,
            humedadPromedio: stats.humedadPromedio,
            pdfData: pdfData
        )
        modelContext.insert(reporte)
        try? modelContext.save()

        // Copiar a URL compartible con nombre de fecha
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let nombre = "Reporte_ResiApp_\(formatter.string(from: .now)).pdf"
        let destino = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        try? pdfData?.write(to: destino)
        pdfURL = destino

        generando = false
        withAnimation(AppAnimation.spring) { mostrarToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation { mostrarToast = false }
        }
    }

    private func compartir(_ r: ReporteProductor) {
        guard let data = r.pdfData else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Reporte_\(formatter.string(from: r.fechaGenerado)).pdf")
        try? data.write(to: url)
        pdfURL = url
        mostrarShare = true
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Vista A4 que ImageRenderer convierte a PDF

struct PDFReporteView: View {
    let perfil: ProducerProfile
    let stats: ReporteProductorView.Stats
    let capturas: [SimulatedCapture]

    private let precioM3: Double = 45.0

    var body: some View {
        VStack(spacing: 0) {

            // ── Cabecera verde ──────────────────────────────────────────
            HStack(spacing: 16) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 3) {
                    Text("EcoVínculo Ganadero")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Reporte de actividad — últimos 30 días")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Date.now, format: .dateTime.day().month(.wide).year())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("ResiApp · v1.0")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(Color.appGreen)

            VStack(alignment: .leading, spacing: 18) {

                // ── Datos del productor ─────────────────────────────────
                pdfSection(titulo: "Productor") {
                    pdfFila("Nombre",        perfil.nombre)
                    pdfFila("Teléfono",      perfil.telefono)
                    pdfFila("Miembro desde", perfil.fechaRegistro.formatted(.dateTime.day().month(.wide).year()))
                    pdfFila("Días activo",   "\(stats.diasActivo) días")
                }

                // ── KPIs en 2 columnas ──────────────────────────────────
                pdfSection(titulo: "Producción · Últimos 30 días") {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            pdfFila("Capturas registradas",  "\(stats.capturasUltimos30)")
                            pdfFila("Volumen total",         String(format: "%.1f m³", stats.volumenUltimos30))
                            pdfFila("Ingreso estimado",      "$\(Int(stats.ingresoEstimado)) MXN")
                        }
                        .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 1)

                        VStack(spacing: 0) {
                            pdfFila("Matches confirmados",   "\(stats.matchesConfirmados)")
                            pdfFila("Matches propuestos",    "\(stats.matchesPropuestos)")
                            pdfFila("Humedad promedio",      String(format: "%.1f%%", stats.humedadPromedio))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    pdfFila("Animal más frecuente", "\(stats.animalTop) (\(stats.capturasAnimalTop) capturas)")
                }

                // ── Precio referencia ───────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.appGreen)
                        .font(.system(size: 11))
                    Text("Ingreso estimado calculado a $\(Int(precioM3)) MXN/m³ (precio referencia mercado biogás México, 2026).")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                // ── Historial de capturas (tabla) ───────────────────────
                if !capturas.isEmpty {
                    pdfSection(titulo: "Historial de capturas") {
                        // Encabezado tabla
                        HStack {
                            Text("Fecha").frame(width: 70, alignment: .leading)
                            Text("Animal").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Vol. m³").frame(width: 55, alignment: .trailing)
                            Text("Hum. %").frame(width: 50, alignment: .trailing)
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))

                        // Filas (máximo 12 para no salirse del A4)
                        ForEach(Array(capturas.prefix(12).enumerated()), id: \.element.id) { idx, c in
                            HStack {
                                Text(c.fecha, format: .dateTime.day().month().year())
                                    .frame(width: 70, alignment: .leading)
                                Text(c.animal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(String(format: "%.0f", c.volumenM3))
                                    .frame(width: 55, alignment: .trailing)
                                Text(String(format: "%.0f", c.humedadPct))
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .font(.system(size: 9))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(idx % 2 == 0 ? Color.white : Color(.systemGray6))
                        }

                        if capturas.count > 12 {
                            Text("… y \(capturas.count - 12) capturas más no mostradas")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 10)

            Spacer()

            // ── Footer ──────────────────────────────────────────────────
            Divider()
            HStack {
                Text("ResiApp © 2026 · EcoVínculo Ganadero")
                Spacer()
                Text("Generado el \(Date.now.formatted(.dateTime.day().month().year())) a las \(Date.now.formatted(.dateTime.hour().minute()))")
            }
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
        }
        .frame(width: 595, height: 842)
        .background(Color.white)
    }

    // Sección con título verde y borde
    @ViewBuilder
    private func pdfSection<C: View>(titulo: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.appGreen)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appGreen.opacity(0.08))

            content()
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    // Fila clave → valor
    @ViewBuilder
    private func pdfFila(_ label: String, _ valor: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(valor)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)

        Divider()
            .padding(.leading, 12)
    }
}
