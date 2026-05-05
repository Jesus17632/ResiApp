//
//  ProcessingPlant.swift
//  EcoVinculo
//
//  Planta procesadora (biogás / compostaje) que recibe pilas de los productores.
//

import Foundation
import SwiftData

@Model
final class ProcessingPlant {
    @Attribute(.unique) var id: UUID
    var nombre: String

    // Ubicación de la planta para cálculo de distancia con CoreLocation.
    var latitud: Double
    var longitud: Double

    // Tipos de procesamiento aceptados, como strings simples ("biogas", "compostaje", etc.)
    // SwiftData soporta arrays de tipos primitivos sin configuración extra.
    var tiposProcesamiento: [String]

    var capacidadTon: Double

    // Rango de humedad aceptable para la pila. Se usa en MatchingEngine (Bloque 3).
    var humedadMinima: Double
    var humedadMaxima: Double

    init(
        id: UUID = UUID(),
        nombre: String,
        latitud: Double,
        longitud: Double,
        tiposProcesamiento: [String] = [],
        capacidadTon: Double = 0,
        humedadMinima: Double = 0,
        humedadMaxima: Double = 100
    ) {
        self.id = id
        self.nombre = nombre
        self.latitud = latitud
        self.longitud = longitud
        self.tiposProcesamiento = tiposProcesamiento
        self.capacidadTon = capacidadTon
        self.humedadMinima = humedadMinima
        self.humedadMaxima = humedadMaxima
    }
}
