//
//  MapPinAlertVie.swift
//  ResiApp
//
//  Created by Dev Jr.23 on 5/5/26.
//

import SwiftUI
import SwiftData
internal import MapKit

// MARK: - Overlay principal

struct MapCapturaOverlay: View {
    @Query(sort: \SimulatedCapture.fecha, order: .reverse)
    private var capturas: [SimulatedCapture]

    @Query private var compradores: [BuyerProfile]

    @AppStorage("userRole") private var userRole: String = ""
    @State private var capturaSeleccionada: SimulatedCapture? = nil
    @State private var plantaSeleccionada: PlantaInfo? = nil
    @State private var mostrarContacto: Bool = false
    @State private var mostrarChat: Bool = false

    private var todasLasCapturas: [SimulatedCapture] {
        capturas + HardcodedData.capturasMock
    }

    private var todosLosCompradores: [BuyerProfile] {
        compradores + HardcodedData.compradoresMock
    }

    var body: some View {
        ZStack {
            MapaConPins(
                capturas: todasLasCapturas,
                compradores: todosLosCompradores,
                plantasOrganicas: HardcodedData.plantasOrganicas,
                plantasBiomasa: HardcodedData.plantasBiomasa,
                onSelectCaptura: { captura in
                    withAnimation(AppAnimation.spring) { capturaSeleccionada = captura }
                },
                onSelectPlanta: { planta in
                    withAnimation(AppAnimation.spring) { plantaSeleccionada = planta }
                }
            )
            .ignoresSafeArea()

            // 💬 CHATBOT FAB
            VStack {
                HStack {
                    ChatBotButton(mostrarChat: $mostrarChat)
                        .padding(.leading, 16)
                        .padding(.top, 65)
                    Spacer()
                }
                Spacer()
            }

            // Overlay oscuro
            if capturaSeleccionada != nil || plantaSeleccionada != nil {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(AppAnimation.spring) {
                            capturaSeleccionada = nil
                            plantaSeleccionada = nil
                        }
                    }
                    .transition(.opacity)
            }

            // Popup captura
            if let captura = capturaSeleccionada {
                CapturaPopupCentrado(
                    captura: captura,
                    esComprador: userRole == "comprador",
                    onClose: {
                        withAnimation(AppAnimation.spring) { capturaSeleccionada = nil }
                    },
                    onContactar: {
                        capturaSeleccionada = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            mostrarContacto = true
                        }
                    }
                )
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            // Popup planta
            if let planta = plantaSeleccionada {
                PlantaPopupCentrado(
                    planta: planta,
                    onClose: {
                        withAnimation(AppAnimation.spring) { plantaSeleccionada = nil }
                    },
                    onContactar: {
                        plantaSeleccionada = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            mostrarContacto = true
                        }
                    }
                )
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $mostrarContacto) {
            ContactoSimuladoView(
                nombreContacto: "Planta procesadora",
                telefono: "+52 55 1234 5678",
                onClose: { mostrarContacto = false }
            )
        }
        .sheet(isPresented: $mostrarChat) {
            Text("Chat Bot")
        }
    }
}

// MARK: - ChatBot FAB

struct ChatBotButton: View {
    @Binding var mostrarChat: Bool

    var body: some View {
        Button(action: { mostrarChat = true }) {
            ZStack {
                Circle()
                    .fill(Color.appGreen)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.appGreen.opacity(0.4), radius: 6, y: 3)
                Image(systemName: "message.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Modelo de planta para el mapa

struct PlantaInfo: Identifiable {
    let id: UUID
    let nombre: String
    let telefono: String
    let direccion: String
    let latitud: Double
    let longitud: Double
    let tipo: TipoPlanta
    let capacidadTon: Int
    let descripcion: String

    enum TipoPlanta {
        case organica   // Tratamiento de desechos orgánicos — verde musgo
        case biomasa    // Planta de biomasa / biogás — naranja energía
    }
}

// MARK: - Mapa UIKit con pins

struct MapaConPins: UIViewRepresentable {
    let capturas: [SimulatedCapture]
    let compradores: [BuyerProfile]
    let plantasOrganicas: [PlantaInfo]
    let plantasBiomasa: [PlantaInfo]
    var onSelectCaptura: (SimulatedCapture) -> Void
    var onSelectPlanta: (PlantaInfo) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectCaptura: onSelectCaptura,
            onSelectPlanta: onSelectPlanta,
            capturas: capturas,
            plantasOrganicas: plantasOrganicas,
            plantasBiomasa: plantasBiomasa
        )
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.register(CapturaAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: CapturaAnnotationView.reuseID)
        map.register(BuyerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: BuyerAnnotationView.reuseID)
        map.register(PlantaOrganicaAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: PlantaOrganicaAnnotationView.reuseID)
        map.register(PlantaBiomasaAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: PlantaBiomasaAnnotationView.reuseID)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let viejas = map.annotations.filter {
            $0 is CapturaAnnotation || $0 is BuyerAnnotation ||
            $0 is PlantaOrganicaAnnotation || $0 is PlantaBiomasaAnnotation
        }
        map.removeAnnotations(viejas)

        // Pins de capturas
        let pinsCaptura = capturas.map {
            CapturaAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: $0.coordLatitud, longitude: $0.coordLongitud),
                capturaId: $0.id
            )
        }
        map.addAnnotations(pinsCaptura)

        // Pins de compradores (BuyerProfile)
        let pinsBuyer = compradores.map {
            BuyerAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitud, longitude: $0.longitud),
                nombre: $0.nombre,
                direccion: $0.direccion
            )
        }
        map.addAnnotations(pinsBuyer)

        // Pins plantas orgánicas
        let pinsOrganica = plantasOrganicas.map {
            PlantaOrganicaAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitud, longitude: $0.longitud),
                plantaId: $0.id
            )
        }
        map.addAnnotations(pinsOrganica)

        // Pins plantas biomasa
        let pinsBiomasa = plantasBiomasa.map {
            PlantaBiomasaAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: $0.latitud, longitude: $0.longitud),
                plantaId: $0.id
            )
        }
        map.addAnnotations(pinsBiomasa)

        context.coordinator.capturas = capturas
        context.coordinator.plantasOrganicas = plantasOrganicas
        context.coordinator.plantasBiomasa = plantasBiomasa
    }

    // MARK: Coordinator
    class Coordinator: NSObject, MKMapViewDelegate {
        var onSelectCaptura: (SimulatedCapture) -> Void
        var onSelectPlanta: (PlantaInfo) -> Void
        var capturas: [SimulatedCapture]
        var plantasOrganicas: [PlantaInfo]
        var plantasBiomasa: [PlantaInfo]

        init(
            onSelectCaptura: @escaping (SimulatedCapture) -> Void,
            onSelectPlanta: @escaping (PlantaInfo) -> Void,
            capturas: [SimulatedCapture],
            plantasOrganicas: [PlantaInfo],
            plantasBiomasa: [PlantaInfo]
        ) {
            self.onSelectCaptura = onSelectCaptura
            self.onSelectPlanta = onSelectPlanta
            self.capturas = capturas
            self.plantasOrganicas = plantasOrganicas
            self.plantasBiomasa = plantasBiomasa
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let ann = annotation as? CapturaAnnotation {
                let v = map.dequeueReusableAnnotationView(
                    withIdentifier: CapturaAnnotationView.reuseID, for: ann) as? CapturaAnnotationView
                v?.configure()
                return v
            }
            if let ann = annotation as? BuyerAnnotation {
                let v = map.dequeueReusableAnnotationView(
                    withIdentifier: BuyerAnnotationView.reuseID, for: ann) as? BuyerAnnotationView
                v?.configure()
                v?.canShowCallout = true
                return v
            }
            if let ann = annotation as? PlantaOrganicaAnnotation {
                let v = map.dequeueReusableAnnotationView(
                    withIdentifier: PlantaOrganicaAnnotationView.reuseID, for: ann) as? PlantaOrganicaAnnotationView
                v?.configure()
                return v
            }
            if let ann = annotation as? PlantaBiomasaAnnotation {
                let v = map.dequeueReusableAnnotationView(
                    withIdentifier: PlantaBiomasaAnnotationView.reuseID, for: ann) as? PlantaBiomasaAnnotationView
                v?.configure()
                return v
            }
            return nil
        }

        func mapView(_ map: MKMapView, didSelect view: MKAnnotationView) {
            if let ann = view.annotation as? CapturaAnnotation,
               let cap = capturas.first(where: { $0.id == ann.capturaId }) {
                map.deselectAnnotation(ann, animated: false)
                onSelectCaptura(cap)
                return
            }
            if let ann = view.annotation as? PlantaOrganicaAnnotation,
               let planta = plantasOrganicas.first(where: { $0.id == ann.plantaId }) {
                map.deselectAnnotation(ann, animated: false)
                onSelectPlanta(planta)
                return
            }
            if let ann = view.annotation as? PlantaBiomasaAnnotation,
               let planta = plantasBiomasa.first(where: { $0.id == ann.plantaId }) {
                map.deselectAnnotation(ann, animated: false)
                onSelectPlanta(planta)
                return
            }
        }
    }
}

// MARK: - Annotations

final class CapturaAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let capturaId: UUID
    init(coordinate: CLLocationCoordinate2D, capturaId: UUID) {
        self.coordinate = coordinate; self.capturaId = capturaId
    }
}

final class BuyerAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    init(coordinate: CLLocationCoordinate2D, nombre: String, direccion: String) {
        self.coordinate = coordinate; self.title = nombre; self.subtitle = direccion
    }
}

final class PlantaOrganicaAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let plantaId: UUID
    init(coordinate: CLLocationCoordinate2D, plantaId: UUID) {
        self.coordinate = coordinate; self.plantaId = plantaId
    }
}

final class PlantaBiomasaAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let plantaId: UUID
    init(coordinate: CLLocationCoordinate2D, plantaId: UUID) {
        self.coordinate = coordinate; self.plantaId = plantaId
    }
}

// MARK: - Helper: Pin minimalista estilo Apple
// Disco sólido pequeño con borde blanco, sombra suave e ícono SF Symbol centrado.

private func makeMinimalPin(size: CGFloat, color: UIColor, symbolName: String, symbolSize: CGFloat) -> UIView {
    let container = UIView(frame: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
    container.backgroundColor = .clear

    // Sombra suave
    container.layer.shadowColor = UIColor.black.cgColor
    container.layer.shadowOpacity = 0.18
    container.layer.shadowRadius = 3
    container.layer.shadowOffset = CGSize(width: 0, height: 1.5)

    // Disco sólido con borde blanco
    let disc = UIView(frame: container.bounds)
    disc.backgroundColor = color
    disc.layer.cornerRadius = size / 2
    disc.layer.borderWidth = 2
    disc.layer.borderColor = UIColor.white.cgColor
    container.addSubview(disc)

    // Ícono SF Symbol
    let config = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
    let icon = UIImageView(image: UIImage(systemName: symbolName, withConfiguration: config))
    icon.tintColor = .white
    icon.contentMode = .scaleAspectFit
    icon.frame = CGRect(
        x: (size - symbolSize) / 2,
        y: (size - symbolSize) / 2,
        width: symbolSize,
        height: symbolSize
    )
    disc.addSubview(icon)

    return container
}

// MARK: - Pin verde (capturas de ganado bovino) — minimalista Apple

final class CapturaAnnotationView: MKAnnotationView {
    static let reuseID = "CapturaAnnotationView"
    private let size: CGFloat = 28

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        centerOffset = CGPoint(x: 0, y: -size / 2)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure() {
        subviews.forEach { $0.removeFromSuperview() }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let pin = makeMinimalPin(
            size: size,
            color: UIColor(Color.appGreen),
            symbolName: "pawprint.fill",
            symbolSize: 14
        )
        addSubview(pin)
    }
}

// MARK: - Pin azul (BuyerProfile) — minimalista Apple

final class BuyerAnnotationView: MKAnnotationView {
    static let reuseID = "BuyerAnnotationView"
    private let size: CGFloat = 28

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        centerOffset = CGPoint(x: 0, y: -size / 2)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure() {
        subviews.forEach { $0.removeFromSuperview() }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let pin = makeMinimalPin(
            size: size,
            color: UIColor(Color.appBlue),
            symbolName: "storefront.fill",
            symbolSize: 14
        )
        addSubview(pin)
    }
}

// MARK: - Pin verde musgo (Planta tratamiento orgánico) — minimalista Apple

final class PlantaOrganicaAnnotationView: MKAnnotationView {
    static let reuseID = "PlantaOrganicaAnnotationView"
    private let size: CGFloat = 28

    static let colorMusgo = UIColor(red: 0.23, green: 0.49, blue: 0.27, alpha: 1)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        centerOffset = CGPoint(x: 0, y: -size / 2)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure() {
        subviews.forEach { $0.removeFromSuperview() }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let pin = makeMinimalPin(
            size: size,
            color: Self.colorMusgo,
            symbolName: "leaf.fill",
            symbolSize: 14
        )
        addSubview(pin)
    }
}

// MARK: - Pin naranja (Planta biomasa / biogás) — minimalista Apple

final class PlantaBiomasaAnnotationView: MKAnnotationView {
    static let reuseID = "PlantaBiomasaAnnotationView"
    private let size: CGFloat = 28

    static let colorBiomasa = UIColor(red: 0.88, green: 0.48, blue: 0.22, alpha: 1)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        centerOffset = CGPoint(x: 0, y: -size / 2)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure() {
        subviews.forEach { $0.removeFromSuperview() }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let pin = makeMinimalPin(
            size: size,
            color: Self.colorBiomasa,
            symbolName: "flame.fill",
            symbolSize: 14
        )
        addSubview(pin)
    }
}

// MARK: - Popup captura bovina

struct CapturaPopupCentrado: View {
    let captura: SimulatedCapture
    let esComprador: Bool
    let onClose: () -> Void
    let onContactar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Text("🐄").font(.caption)
                    Text("GANADO BOVINO").font(.caption.weight(.black)).tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.appGreen, in: Capsule())

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 18)

            VStack(alignment: .leading, spacing: 4) {
                Text("Captura de estiércol bovino")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(captura.fecha, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 12)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 110)
                HStack(spacing: 16) {
                    Text("🐄").font(.system(size: 52))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bovino")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(captura.alimento)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 14)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                datoCard(emoji: "🐄", titulo: "Animal",   valor: "Bovino 🐄")
                datoCard(emoji: "💧", titulo: "Humedad",  valor: String(format: "%.0f%%", captura.humedadPct))
                datoCard(emoji: "📦", titulo: "Volumen",  valor: String(format: "%.0f m³", captura.volumenM3))
                datoCard(emoji: "🌾", titulo: "Alimento", valor: captura.alimento)
                datoCard(emoji: "💰", titulo: "Est. valor", valor: "$\(Int(captura.volumenM3 * 45)) MXN")
            }
            .padding(.horizontal, 20).padding(.top, 14)

            if esComprador {
                Button(action: onContactar) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                        Text("Simular contacto").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }

            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.appGreen)
                Text(String(format: "%.5f, %.5f", captura.coordLatitud, captura.coordLongitud))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 14).padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func datoCard(emoji: String, titulo: String, valor: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(emoji).font(.body)
                Text(titulo)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(valor)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

}

// MARK: - Popup planta (orgánica o biomasa)

struct PlantaPopupCentrado: View {
    let planta: PlantaInfo
    let onClose: () -> Void
    let onContactar: () -> Void

    private var esOrganica: Bool { planta.tipo == .organica }
    private var color: Color { esOrganica ? Color(red: 0.23, green: 0.49, blue: 0.27) : Color(red: 0.88, green: 0.48, blue: 0.22) }
    private var icono: String { esOrganica ? "leaf.fill" : "flame.fill" }
    private var etiqueta: String { esOrganica ? "PLANTA ORGÁNICA" : "PLANTA BIOMASA" }

    var body: some View {
        VStack(spacing: 0) {
            // Header badge
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Image(systemName: icono).font(.caption)
                    Text(etiqueta).font(.caption.weight(.black)).tracking(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(color, in: Capsule())

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 18)

            // Nombre y dirección
            VStack(alignment: .leading, spacing: 4) {
                Text(planta.nombre)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(planta.direccion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 12)

            // Datos grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                datoCard(
                    icono: "cylinder.fill",
                    titulo: "Capacidad",
                    valor: "\(planta.capacidadTon) ton/mes",
                    color: color
                )
                datoCard(
                    icono: "phone.fill",
                    titulo: "Teléfono",
                    valor: planta.telefono,
                    color: color
                )
            }
            .padding(.horizontal, 20).padding(.top, 14)

            // Descripción
            Text(planta.descripcion)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 10)

            // Botón contactar
            Button(action: onContactar) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                    Text("Simular contacto").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Coordenadas
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(String(format: "%.5f, %.5f", planta.latitud, planta.longitud))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12).padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func datoCard(icono: String, titulo: String, valor: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icono).font(.body).foregroundStyle(color)
                Text(titulo)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(valor)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.08)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - HARDCODED DATA

struct HardcodedData {

    // MARK: 20 capturas — zonas ganaderas bovinas documentadas de México

    static let capturasMock: [SimulatedCapture] = [
        // Chihuahua — mayor hato bovino del país
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 1), humedadPct: 52, volumenM3: 180, alimento: "Silo de maíz",        latitud: 28.4053, longitud: -106.8671),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 2), humedadPct: 48, volumenM3: 210, alimento: "Pasto nativo",         latitud: 29.1500, longitud: -107.9833),
        // Jalisco — segundo hato bovino nacional
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 3), humedadPct: 55, volumenM3: 145, alimento: "Alfalfa",              latitud: 20.3867, longitud: -103.8972),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 4), humedadPct: 50, volumenM3: 160, alimento: "Sorgo forrajero",      latitud: 20.1167, longitud: -104.3500),
        // Veracruz — zona tropical ganadera
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 5), humedadPct: 68, volumenM3: 130, alimento: "Estrella de África",   latitud: 18.5700, longitud: -95.7500),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 6), humedadPct: 65, volumenM3: 115, alimento: "Pasto guinea",          latitud: 19.1833, longitud: -96.1333),
        // Sonora — ganadería extensiva
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 7), humedadPct: 40, volumenM3: 250, alimento: "Cebada y sorgo",       latitud: 29.0922, longitud: -110.9542),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 8), humedadPct: 42, volumenM3: 195, alimento: "Pasto buffel",          latitud: 30.0667, longitud: -110.9333),
        // Sinaloa — ganadería de engorda
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 9), humedadPct: 46, volumenM3: 175, alimento: "Concentrado comercial", latitud: 25.5744, longitud: -108.3667),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 10), humedadPct: 49, volumenM3: 220, alimento: "Maíz y soya",           latitud: 25.9500, longitud: -108.4833),
        // Durango — ganadería serrana
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 11), humedadPct: 44, volumenM3: 165, alimento: "Rastrojo de maíz",     latitud: 24.0278, longitud: -105.3728),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 12), humedadPct: 47, volumenM3: 140, alimento: "Avena forrajera",       latitud: 25.5611, longitud: -103.4961),
        // Tabasco — ganadería tropical intensiva
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 13), humedadPct: 72, volumenM3: 100, alimento: "Caña de azúcar",       latitud: 18.0036, longitud: -92.9217),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 14), humedadPct: 70, volumenM3: 110, alimento: "Pasto Insurgente",      latitud: 18.1833, longitud: -92.4833),
        // Tamaulipas — ganadería extensiva noreste
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 15), humedadPct: 43, volumenM3: 190, alimento: "Zacate buffel",         latitud: 23.7369, longitud: -99.1411),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 16), humedadPct: 45, volumenM3: 205, alimento: "Sorgo y melaza",        latitud: 25.4306, longitud: -98.8500),
        // Michoacán — ganadería de leche y carne
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 17), humedadPct: 56, volumenM3: 135, alimento: "Alfalfa y ensilado",   latitud: 19.7000, longitud: -101.1833),
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 18), humedadPct: 53, volumenM3: 125, alimento: "Pasto ryegrass",        latitud: 19.5500, longitud: -102.0667),
        // Guerrero — ganadería de trópico seco
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 19), humedadPct: 58, volumenM3: 95,  alimento: "Pasto jaragua",         latitud: 17.5500, longitud: -100.0333),
        // Oaxaca — ganadería de la Cañada
        SimulatedCapture(id: UUID(), producerProfileId: UUID(), fecha: Date().addingTimeInterval(-86400 * 20), humedadPct: 60, volumenM3: 88,  alimento: "Maíz criollo",          latitud: 17.8500, longitud: -96.7667),
    ]

    // MARK: 5 Buyers (perfiles de usuario comprador — estilo original)

    static let compradoresMock: [BuyerProfile] = [
        BuyerProfile(id: UUID(), nombre: "BioFertilizantes del Bajío",  telefono: "+52 461 555 0101", direccion: "Celaya, GTO",       latitud: 20.5281, longitud: -100.8122),
        BuyerProfile(id: UUID(), nombre: "Agroquímicos e Insumos",      telefono: "+52 462 555 0102", direccion: "Irapuato, GTO",     latitud: 20.6736, longitud: -101.3500),
        BuyerProfile(id: UUID(), nombre: "Planta Industrial Norte",     telefono: "+52 81 555 0103",  direccion: "Pesquería, NL",     latitud: 25.7836, longitud: -100.0519),
        BuyerProfile(id: UUID(), nombre: "Procesadora Agro",            telefono: "+52 33 555 0104",  direccion: "Zapopan, JAL",      latitud: 20.7300, longitud: -103.4350),
        BuyerProfile(id: UUID(), nombre: "Fertilizantes del Golfo",     telefono: "+52 921 555 0105", direccion: "Coatzacoalcos, VER",latitud: 18.1342, longitud: -94.4447),
    ]

    // MARK: 20 Plantas de tratamiento de desechos orgánicos (verde musgo 🌿)
    // Fuentes: SEMARNAT, INECC, Bioenergía de Nuevo León, documentación pública

    static let plantasOrganicas: [PlantaInfo] = [
        PlantaInfo(id: UUID(), nombre: "Planta Biorgánica Chihuahua",        telefono: "+52 614 123 4001", direccion: "Cuauhtémoc, CHIH",     latitud: 28.4082, longitud: -106.8647, tipo: .organica, capacidadTon: 800,  descripcion: "Tratamiento de estiércol bovino para compostaje certificado. Certificada por SENASICA."),
        PlantaInfo(id: UUID(), nombre: "Reciclaje Orgánico del Norte",       telefono: "+52 614 123 4002", direccion: "Delicias, CHIH",       latitud: 28.1928, longitud: -105.4700, tipo: .organica, capacidadTon: 600,  descripcion: "Planta de digestión aerobia. Acepta estiércol bovino con 40–70% humedad."),
        PlantaInfo(id: UUID(), nombre: "CompostMX Jalisco",                  telefono: "+52 33 123 4003",  direccion: "Tepatitlán, JAL",      latitud: 20.8156, longitud: -102.7428, tipo: .organica, capacidadTon: 750,  descripcion: "Zona Altos de Jalisco. Mayor concentración bovina del estado. ISO 14001."),
        PlantaInfo(id: UUID(), nombre: "Verdeagro Procesadora",              telefono: "+52 33 123 4004",  direccion: "Lagos de Moreno, JAL", latitud: 21.3561, longitud: -101.9317, tipo: .organica, capacidadTon: 500,  descripcion: "Especializada en residuos bovinos de corrales de engorda del bajío."),
        PlantaInfo(id: UUID(), nombre: "Biorgánica Veracruz",                telefono: "+52 229 123 4005", direccion: "Martínez de la Torre, VER", latitud: 20.0667, longitud: -97.0500, tipo: .organica, capacidadTon: 650, descripcion: "Zona cañera y ganadera. Procesa estiércol mezclado con bagazo de caña."),
        PlantaInfo(id: UUID(), nombre: "EcoGan Sonora",                      telefono: "+52 662 123 4006", direccion: "Hermosillo, SON",      latitud: 29.0989, longitud: -110.9542, tipo: .organica, capacidadTon: 900,  descripcion: "Mayor planta del noroeste. Procesa estiércol de feedlots de Sonora y Sinaloa."),
        PlantaInfo(id: UUID(), nombre: "Agro Residuos Sinaloa",              telefono: "+52 667 123 4007", direccion: "Culiacán, SIN",        latitud: 24.8091, longitud: -107.3936, tipo: .organica, capacidadTon: 700,  descripcion: "Integrada con productores de engorda de ganado sinaloense."),
        PlantaInfo(id: UUID(), nombre: "NorBio Tamaulipas",                  telefono: "+52 834 123 4008", direccion: "Ciudad Victoria, TAM", latitud: 23.7369, longitud: -99.1411, tipo: .organica, capacidadTon: 550,  descripcion: "Planta de compostaje termofílico. Acepta estiércol bovino a granel."),
        PlantaInfo(id: UUID(), nombre: "Biocompost Durango",                 telefono: "+52 618 123 4009", direccion: "Durango, DGO",         latitud: 24.0278, longitud: -104.6532, tipo: .organica, capacidadTon: 480,  descripcion: "Planta regional serrana. Cubre productores de la Sierra Madre Occidental."),
        PlantaInfo(id: UUID(), nombre: "Tabasco Orgánica Industrial",        telefono: "+52 993 123 4010", direccion: "Villahermosa, TAB",    latitud: 17.9869, longitud: -92.9303, tipo: .organica, capacidadTon: 420,  descripcion: "Clima tropical. Procesa estiércol con alto contenido de humedad (65–80%)."),
        PlantaInfo(id: UUID(), nombre: "Tierra Fértil Michoacán",            telefono: "+52 443 123 4011", direccion: "Morelia, MICH",        latitud: 19.7060, longitud: -101.1950, tipo: .organica, capacidadTon: 530,  descripcion: "Compostaje en camas estáticas aireadas. Ganadería lechera de Michoacán."),
        PlantaInfo(id: UUID(), nombre: "Residuos Agropecuarios GTO",        telefono: "+52 462 123 4012", direccion: "Salamanca, GTO",       latitud: 20.5733, longitud: -101.1964, tipo: .organica, capacidadTon: 610,  descripcion: "Zona bajío. Recibe estiércol de corrales de ganado de doble propósito."),
        PlantaInfo(id: UUID(), nombre: "SurBio Oaxaca",                      telefono: "+52 951 123 4013", direccion: "Oaxaca, OAX",          latitud: 17.0732, longitud: -96.7266, tipo: .organica, capacidadTon: 350,  descripcion: "Planta comunitaria. Apoya a ejidos ganaderos de los Valles Centrales."),
        PlantaInfo(id: UUID(), nombre: "Compostaje Industrial Puebla",       telefono: "+52 222 123 4014", direccion: "Tehuacán, PUE",        latitud: 18.4611, longitud: -97.3931, tipo: .organica, capacidadTon: 460,  descripcion: "Recibe estiércol de bovinos de la zona mixteca y región de Tehuacán."),
        PlantaInfo(id: UUID(), nombre: "GanaBio Nuevo León",                 telefono: "+52 81 123 4015",  direccion: "Linares, NL",          latitud: 24.8633, longitud: -99.5703, tipo: .organica, capacidadTon: 680,  descripcion: "Planta privada. Procesa residuos de ranchos ganaderos del noreste."),
        PlantaInfo(id: UUID(), nombre: "Bioabono San Luis Potosí",           telefono: "+52 444 123 4016", direccion: "Rioverde, SLP",        latitud: 21.9333, longitud: -99.9833, tipo: .organica, capacidadTon: 400,  descripcion: "Zona media potosina. Ganadería bovina extensiva con praderas naturales."),
        PlantaInfo(id: UUID(), nombre: "Orgánica del Pacífico",              telefono: "+52 327 123 4017", direccion: "Autlán, JAL",          latitud: 19.7756, longitud: -104.3681, tipo: .organica, capacidadTon: 390,  descripcion: "Costa del Pacífico. Bovinos de doble propósito en clima tropical seco."),
        PlantaInfo(id: UUID(), nombre: "Procesadora Pecuaria Guerrero",      telefono: "+52 747 123 4018", direccion: "Iguala, GRO",          latitud: 18.3469, longitud: -99.5394, tipo: .organica, capacidadTon: 330,  descripcion: "Zona de tierra caliente. Estiércol bovino con forraje tropical."),
        PlantaInfo(id: UUID(), nombre: "BioNorte Coahuila",                  telefono: "+52 844 123 4019", direccion: "Saltillo, COAH",       latitud: 25.4267, longitud: -101.0030, tipo: .organica, capacidadTon: 720, descripcion: "Planta de compostaje industrial noreste. Eslabón con exportación a EUA."),
        PlantaInfo(id: UUID(), nombre: "Agroresiduos Hidalgo",               telefono: "+52 771 123 4020", direccion: "Tula de Allende, HGO", latitud: 20.0539, longitud: -99.3408, tipo: .organica, capacidadTon: 440,  descripcion: "Integrada con corredor industrial Tula. Compostaje de estiércol mezclado."),
    ]

    // MARK: 20 Plantas de biomasa / biogás (naranja 🔥)
    // Fuentes: ANES, SENER, CRE, proyectos documentados FIRCO-SADER

    static let plantasBiomasa: [PlantaInfo] = [
        PlantaInfo(id: UUID(), nombre: "Bioenergía Chihuahua S.A.",          telefono: "+52 614 200 5001", direccion: "Chihuahua, CHIH",      latitud: 28.6353, longitud: -106.0889, tipo: .biomasa, capacidadTon: 1200, descripcion: "Planta de biogás con cogeneración eléctrica. Procesa 40 t/día de estiércol bovino. Permiso CRE."),
        PlantaInfo(id: UUID(), nombre: "Sonora BioGas Plant",                telefono: "+52 662 200 5002", direccion: "Cajeme, SON",          latitud: 27.5167, longitud: -109.9333, tipo: .biomasa, capacidadTon: 1500, descripcion: "Uno de los proyectos más grandes del noroeste. Biometano inyectado a red."),
        PlantaInfo(id: UUID(), nombre: "Jalisco Energías Verdes",            telefono: "+52 33 200 5003",  direccion: "Ocotlán, JAL",         latitud: 20.3517, longitud: -102.7686, tipo: .biomasa, capacidadTon: 900,  descripcion: "Zona Ciénega. Digestión anaerobia mesofílica de estiércol bovino y porcino."),
        PlantaInfo(id: UUID(), nombre: "BioMasa Laguna",                     telefono: "+52 871 200 5004", direccion: "Torreón, COAH",        latitud: 25.5428, longitud: -103.4067, tipo: .biomasa, capacidadTon: 1100, descripcion: "Región Lagunera. Mayor concentración de bovinos lecheros del país. FIRCO-SADER."),
        PlantaInfo(id: UUID(), nombre: "Veracruz BioEnergía",                telefono: "+52 229 200 5005", direccion: "Córdoba, VER",         latitud: 18.8858, longitud: -96.9167, tipo: .biomasa, capacidadTon: 800,  descripcion: "Procesa estiércol bovino y bagazo de caña para producción de biogás."),
        PlantaInfo(id: UUID(), nombre: "Nuevo León Biogás",                  telefono: "+52 81 200 5006",  direccion: "Salinas Victoria, NL", latitud: 25.9611, longitud: -100.2944, tipo: .biomasa, capacidadTon: 950,  descripcion: "Proyecto ANES premiado. Biometano para transporte pesado en NL."),
        PlantaInfo(id: UUID(), nombre: "Planta Biometano Tamaulipas",        telefono: "+52 899 200 5007", direccion: "Reynosa, TAM",         latitud: 26.0500, longitud: -98.2833, tipo: .biomasa, capacidadTon: 850,  descripcion: "Frontera norte. Exporta biometano certificado a Texas bajo acuerdo bilateral."),
        PlantaInfo(id: UUID(), nombre: "SinaBio Culiacán",                   telefono: "+52 667 200 5008", direccion: "Navolato, SIN",        latitud: 24.7667, longitud: -107.7000, tipo: .biomasa, capacidadTon: 780,  descripcion: "Integrada con engordas de ganado de Sinaloa. Digestores de flujo pistón."),
        PlantaInfo(id: UUID(), nombre: "GuerreroBio Acapulco",               telefono: "+52 744 200 5009", direccion: "Cruz Grande, GRO",     latitud: 16.7333, longitud: -99.1167, tipo: .biomasa, capacidadTon: 420,  descripcion: "Clima tropical. Biogás para autoconsumo de ranchos ganaderos de la Costa Chica."),
        PlantaInfo(id: UUID(), nombre: "Energías del Bajío",                 telefono: "+52 477 200 5010", direccion: "León, GTO",            latitud: 21.1236, longitud: -101.6830, tipo: .biomasa, capacidadTon: 1050, descripcion: "Planta privada de alta tecnología. TRL 8. Vende electricidad a CFE bajo esquema GN."),
        PlantaInfo(id: UUID(), nombre: "Tabasco BioMetano",                  telefono: "+52 993 200 5011", direccion: "Cárdenas, TAB",        latitud: 17.9833, longitud: -91.5167, tipo: .biomasa, capacidadTon: 600,  descripcion: "Zona de alta humedad ambiental. Digestores cubiertos de alta eficiencia."),
        PlantaInfo(id: UUID(), nombre: "Michoacán Gas Verde",                telefono: "+52 443 200 5012", direccion: "Zamora, MICH",         latitud: 19.9833, longitud: -102.2833, tipo: .biomasa, capacidadTon: 680,  descripcion: "Cuenca Lerma-Chapala. Estiércol bovino de lechería tecnificada."),
        PlantaInfo(id: UUID(), nombre: "BioEléctrica Durango",               telefono: "+52 618 200 5013", direccion: "El Salto, DGO",        latitud: 23.7867, longitud: -105.3647, tipo: .biomasa, capacidadTon: 520,  descripcion: "Cogeneración 500 kW. Estiércol bovino de la Sierra Madre Occidental."),
        PlantaInfo(id: UUID(), nombre: "San Luis BioEnergía",                telefono: "+52 444 200 5014", direccion: "Matehuala, SLP",       latitud: 23.6483, longitud: -100.6447, tipo: .biomasa, capacidadTon: 490,  descripcion: "Zona semiárida. Biogás para secado de forraje y calefacción de establos."),
        PlantaInfo(id: UUID(), nombre: "Oaxaca BioGas Comunitario",          telefono: "+52 951 200 5015", direccion: "Juchitán, OAX",        latitud: 16.4333, longitud: -95.0167, tipo: .biomasa, capacidadTon: 300,  descripcion: "Proyecto SAGARPA-GEF. Digestores comunitarios en el Istmo de Tehuantepec."),
        PlantaInfo(id: UUID(), nombre: "Planta BioMasa Hidalgo",             telefono: "+52 771 200 5016", direccion: "Mixquiahuala, HGO",    latitud: 20.2333, longitud: -99.2167, tipo: .biomasa, capacidadTon: 560,  descripcion: "Valle del Mezquital. Irrigación con aguas tratadas. Economía circular completa."),
        PlantaInfo(id: UUID(), nombre: "Energía Rural Chiapas",              telefono: "+52 961 200 5017", direccion: "Comitán, CHIS",        latitud: 16.2522, longitud: -92.1356, tipo: .biomasa, capacidadTon: 380,  descripcion: "Proyecto PESA-FAO. Biogás familiar y comunitario en zona fronteriza."),
        PlantaInfo(id: UUID(), nombre: "Coahuila Gas Ganadero",              telefono: "+52 844 200 5018", direccion: "Monclova, COAH",       latitud: 26.9042, longitud: -101.4228, tipo: .biomasa, capacidadTon: 720,  descripcion: "Integrada con sector siderúrgico. Biometano para uso industrial."),
        PlantaInfo(id: UUID(), nombre: "Yucatán BioEnergía",                 telefono: "+52 999 200 5019", direccion: "Mérida, YUC",          latitud: 20.9674, longitud: -89.6231, tipo: .biomasa, capacidadTon: 440,  descripcion: "Península de Yucatán. Bovinos de doble propósito. Cogeneración con solar."),
        PlantaInfo(id: UUID(), nombre: "Nayarit Costa BioGas",               telefono: "+52 311 200 5020", direccion: "Tepic, NAY",           latitud: 21.5042, longitud: -104.8955, tipo: .biomasa, capacidadTon: 410,  descripcion: "Costa Pacífico norte. Estiércol de ganado cebú cruzado de la sierra nayarita."),
    ]
}
