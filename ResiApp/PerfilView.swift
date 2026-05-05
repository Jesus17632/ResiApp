//
//  PerfilView.swift
//  EcoVinculo
//
//  Pestaña de perfil: muestra el rol actual y permite resetearlo,
//  lo que regresa al usuario a RolSelectorView en el siguiente render.
//

import SwiftUI

struct PerfilView: View {
    @AppStorage("userRole") private var userRole: String = ""
    @State private var mostrarConfirmacion = false

    var body: some View {
        NavigationStack {
            List {
                Section("Mi rol") {
                    HStack(spacing: 12) {
                        Image(systemName: rolIcono)
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        Text(rolNombre)
                            .font(.body)
                        Spacer()
                    }
                }

                Section {
                    Button(role: .destructive) {
                        mostrarConfirmacion = true
                    } label: {
                        Label("Cambiar rol", systemImage: "arrow.triangle.2.circlepath")
                    }
                } footer: {
                    Text("Al cambiar de rol regresarás a la pantalla de selección inicial.")
                }
            }
            .navigationTitle("Perfil")
            .alert("¿Cambiar rol?", isPresented: $mostrarConfirmacion) {
                Button("Cancelar", role: .cancel) {}
                Button("Cambiar", role: .destructive) {
                    // Vaciar el AppStorage hace que RootView vuelva a mostrar
                    // RolSelectorView automáticamente (es una observación reactiva).
                    userRole = ""
                }
            } message: {
                Text("Volverás a la pantalla de selección de rol.")
            }
        }
    }

    // MARK: - Helpers de presentación

    private var rolNombre: String {
        switch userRole {
        case "productor": return "Productor"
        case "comprador": return "Comprador"
        default:          return "Sin definir"
        }
    }

    private var rolIcono: String {
        switch userRole {
        case "productor": return "leaf.fill"
        case "comprador": return "building.2.fill"
        default:          return "questionmark.circle"
        }
    }
}

#Preview {
    PerfilView()
}
