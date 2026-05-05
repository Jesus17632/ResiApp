//
//  SimulatedCapture.swift
//  ResiApp
//
//  La app sirve exclusivamente a productores de ganado bovino.
//  No hay enum de especies; todas las capturas son bovinas por construcción.
//

import Foundation
import SwiftData

@Model
final class SimulatedCapture {
    @Attribute(.unique) var id: UUID

    /// Referencia al productor dueño de esta captura
    var producerProfileId: UUID

    var fecha: Date
    var animal: String          // siempre "Bovino 🐄"
    var humedadPct: Double      // 0–100
    var volumenM3: Double       // metros cúbicos
    var alimento: String        // forraje específico

    /// Coordenadas donde se generó el pin en el mapa
    var latitud: Double
    var longitud: Double

    /// Pequeño offset aleatorio para que los pins no se superpongan
    var latOffset: Double
    var lonOffset: Double

    init(
        id: UUID = UUID(),
        producerProfileId: UUID,
        fecha: Date = .now,
        humedadPct: Double,
        volumenM3: Double,
        alimento: String,
        latitud: Double,
        longitud: Double,
        latOffset: Double = Double.random(in: -0.002...0.002),
        lonOffset: Double = Double.random(in: -0.002...0.002)
    ) {
        self.id = id
        self.producerProfileId = producerProfileId
        self.fecha = fecha
        self.animal = "Bovino 🐄"   // valor fijo, sin parámetro
        self.humedadPct = humedadPct
        self.volumenM3 = volumenM3
        self.alimento = alimento
        self.latitud = latitud
        self.longitud = longitud
        self.latOffset = latOffset
        self.lonOffset = lonOffset
    }

    /// Coordenada efectiva en el mapa (con offset para no solapar)
    var coordLatitud: Double { latitud + latOffset }
    var coordLongitud: Double { longitud + lonOffset }
}

// MARK: - Factory de datos aleatorios

extension SimulatedCapture {
    /// Constante única de especie. La app es bovina por diseño.
    static let animalFuente: String = "Bovino 🐄"

    /// Forrajes representativos para ganado bovino en México.
    static let alimentosBovinos: [String] = [
        "Silo de maíz", "Alfalfa", "Pasto estrella", "Sorgo forrajero", "Rastrojo de maíz"
    ]

    static func aleatorio(profileId: UUID, lat: Double, lon: Double) -> SimulatedCapture {
        SimulatedCapture(
            producerProfileId: profileId,
            humedadPct: Double.random(in: 55...85).rounded(),
            volumenM3: Double(Int.random(in: 2...30)),
            alimento: alimentosBovinos.randomElement()!,
            latitud: lat,
            longitud: lon
        )
    }
}
