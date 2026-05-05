//
//  ReporteProductor.swift
//  ResiApp
//
//  Created by Dev Jr.23 on 5/5/26.
//

import Foundation
import SwiftData

@Model
final class ReporteProductor {
    @Attribute(.unique) var id: UUID
    var producerProfileId: UUID
    var fechaGenerado: Date

    // — Snapshot de métricas (últimos 30 días) —
    var totalCapturas: Int
    var volumenTotalM3: Double
    var diasActivo: Int
    var capturasUltimos30: Int
    var matchesConfirmados: Int
    var matchesPropuestos: Int
    var ingresoEstimado: Double       // volumen × precio promedio mercado (~$45 MXN/m³)
    var animalMasFrecuente: String
    var humedadPromedio: Double

    // PDF en bytes (guardado fuera de la DB principal)
    @Attribute(.externalStorage) var pdfData: Data?

    init(
        id: UUID = UUID(),
        producerProfileId: UUID,
        fechaGenerado: Date = .now,
        totalCapturas: Int,
        volumenTotalM3: Double,
        diasActivo: Int,
        capturasUltimos30: Int,
        matchesConfirmados: Int,
        matchesPropuestos: Int,
        ingresoEstimado: Double,
        animalMasFrecuente: String,
        humedadPromedio: Double,
        pdfData: Data? = nil
    ) {
        self.id = id
        self.producerProfileId = producerProfileId
        self.fechaGenerado = fechaGenerado
        self.totalCapturas = totalCapturas
        self.volumenTotalM3 = volumenTotalM3
        self.diasActivo = diasActivo
        self.capturasUltimos30 = capturasUltimos30
        self.matchesConfirmados = matchesConfirmados
        self.matchesPropuestos = matchesPropuestos
        self.ingresoEstimado = ingresoEstimado
        self.animalMasFrecuente = animalMasFrecuente
        self.humedadPromedio = humedadPromedio
        self.pdfData = pdfData
    }
}
