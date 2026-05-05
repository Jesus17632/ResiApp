//
//  MarketplaceView.swift
//  EcoVinculo
//
//  Pestaña del comprador: lista de pilas disponibles para procesar.
//  La distancia se calcula en tiempo real con CoreLocation contra la
//  ubicación actual del comprador (LocationManager).
//  Cada card permite navegar a MatchResultView (Bloque 3).
//

import SwiftUI
import SwiftData
import CoreLocation
internal import MapKit

struct MarketplaceView: View {

    // El predicado compara contra el campo almacenado syncStatusRaw,
    // no contra la propiedad calculada syncStatus (que el motor de
    // predicados de SwiftData no puede evaluar).
    @Query(
        filter: #Predicate<ManurePile> { $0.syncStatusRaw == "available" },
        sort: \ManurePile.fecha,
        order: .reverse
    )
    private var pilesDisponibles: [ManurePile]

    @State private var filtroTipo: String = "todos"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filtros

                if pilesDisponibles.isEmpty {
                    estadoVacio
                } else {
                    List {
                        ForEach(pilesDisponibles) { pile in
                            PileCard(pile: pile)
                                .listRowSeparator(.hidden)
                                .listRowInsets(
                                    EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                                )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Marketplace")
        }
    }

    // MARK: - Filtros (placeholder, lógica completa en Bloque 3)

    private var filtros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filtroChip("Todos", id: "todos")
                filtroChip("Biogás", id: "biogas")
                filtroChip("Compostaje", id: "compostaje")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func filtroChip(_ titulo: String, id: String) -> some View {
        let activo = (filtroTipo == id)
        Button {
            filtroTipo = id
        } label: {
            Text(titulo)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(activo ? Color.green : Color(.secondarySystemBackground))
                .foregroundStyle(activo ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Estado vacío

    private var estadoVacio: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Aún no hay pilas disponibles")
                .font(.headline)
            Text("Cuando un productor publique una pila apta, aparecerá aquí.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card para cada pila

struct PileCard: View {
    let pile: ManurePile

    // Lee el LocationManager compartido para calcular distancia real.
    @Environment(LocationManager.self) private var locationManager

    /// Distancia en kilómetros entre la pila y el comprador.
    /// Usa CoreLocation para el cálculo geodésico (más preciso que pitágoras).
    private var distanciaKm: Double {
        let buyerCoord = locationManager.region.center
        let buyerLocation = CLLocation(
            latitude: buyerCoord.latitude,
            longitude: buyerCoord.longitude
        )
        let pileLocation = CLLocation(
            latitude: pile.latitud,
            longitude: pile.longitud
        )
        return pileLocation.distance(from: buyerLocation) / 1000.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(pile.volumenM3, specifier: "%.1f") m³")
                        .font(.title3.bold())
                    Text("Humedad: \(pile.humedadPct, specifier: "%.0f")%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.green)
                    Text("~\(distanciaKm, specifier: "%.1f") km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text(pile.fecha, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Ver Match") {
                    // Bloque 3: navegará a MatchResultView con la planta recomendada.
                    print("👉 Ver Match para pile id: \(pile.id)")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}   
