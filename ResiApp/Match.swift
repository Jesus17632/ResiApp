//
//  Match.swift
//  EcoVinculo
//
//  Conexión productor-comprador propuesta por MatchingEngine (Bloque 3).
//  Usamos UUIDs sueltos en lugar de @Relationship para mantener la lógica
//  de sincronización con backend simple (Firebase en Bloque 2/3).
//

import Foundation
import SwiftData

enum MatchEstado: String, Codable {
    case propuesto    // Sugerido por el motor, pendiente de confirmación humana
    case confirmado   // El usuario aceptó el match
    case rechazado    // El usuario lo descartó
}

@Model
final class Match {
    @Attribute(.unique) var id: UUID
    var pileId: UUID
    var plantId: UUID
    var fecha: Date
    var estadoRaw: String
    var distanciaKm: Double

    var estado: MatchEstado {
        get { MatchEstado(rawValue: estadoRaw) ?? .propuesto }
        set { estadoRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        pileId: UUID,
        plantId: UUID,
        fecha: Date = .now,
        estado: MatchEstado = .propuesto,
        distanciaKm: Double = 0
    ) {
        self.id = id
        self.pileId = pileId
        self.plantId = plantId
        self.fecha = fecha
        self.estadoRaw = estado.rawValue
        self.distanciaKm = distanciaKm
    }
}
