//
//  RolSelectorView.swift
//  EcoVinculo
//
//  Pantalla de bienvenida del primer lanzamiento. El usuario debe elegir
//  un rol antes de continuar; no hay forma de cerrarla sin elegir.
//

import SwiftUI

struct RolSelectorView: View {
    @AppStorage("userRole") private var userRole: String = ""

    var body: some View {
        VStack(spacing: 32) {
            // Encabezado / branding
            VStack(spacing: 12) {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.green)

                Text("EcoVínculo Ganadero")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Elige tu rol para empezar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)

            Spacer()

            // Dos botones grandes con ícono y descripción
            VStack(spacing: 20) {
                rolButton(
                    icono: "leaf.fill",
                    titulo: "Soy Productor",
                    descripcion: "Tengo estiércol que quiero aprovechar"
                ) {
                    userRole = "productor"
                }

                rolButton(
                    icono: "building.2.fill",
                    titulo: "Soy Comprador",
                    descripcion: "Proceso material para biogás o compostaje"
                ) {
                    userRole = "comprador"
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    /// Card-button reutilizable para cada rol.
    @ViewBuilder
    private func rolButton(
        icono: String,
        titulo: String,
        descripcion: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icono)
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                    .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(descripcion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RolSelectorView()
}
