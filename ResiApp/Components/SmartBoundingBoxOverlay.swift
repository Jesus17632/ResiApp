//
//  SmartBoundingBoxOverlay.swift
//  ResiApp
//
//  Recuadro de enfoque ESTÁTICO estilo Apple/Tlane.
//
//  - Tamaño fijo (260×260) centrado en pantalla.
//  - Cuatro corner brackets verdes con un pulse muy sutil (PhaseAnimator).
//  - Estados visuales: scanning (brackets normales) y locked (brackets sólidos
//    + ligero highlight verde dentro del cuadro).
//
//  El recuadro NO sigue al objeto. El usuario centra la pila adentro.
//  El detector ligero (ManureDetector) solo decide CUÁNDO disparar el análisis
//  pesado, no DÓNDE pintar nada.
//

import SwiftUI

struct SmartBoundingBoxOverlay: View {
    let isLocked: Bool

    /// Tamaño del recuadro de enfoque, en puntos. Igual que Tlane.
    private let frameSize: CGFloat = 260

    var body: some View {
        ZStack {
            // Tint sutil dentro del recuadro cuando hace lock — refuerza visualmente
            // que la captura ya se "comprometió", sin ser invasivo.
            if isLocked {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.tlaneGreen.opacity(0.12))
                    .frame(width: frameSize, height: frameSize)
            }

            FocusFrame(isLocked: isLocked)
                .frame(width: frameSize, height: frameSize)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Focus frame con PhaseAnimator

private struct FocusFrame: View {
    let isLocked: Bool

    var body: some View {
        PhaseAnimator([0, 1]) { phase in
            ZStack {
                ForEach(FocusCorner.allCases, id: \.self) { corner in
                    CornerBracketShape(corner: corner)
                        .stroke(Color.tlaneGreen, lineWidth: isLocked ? 5 : 4)
                        .opacity(isLocked ? 1.0 : (phase == 0 ? 0.7 : 1.0))
                        .scaleEffect(isLocked ? 1.04 : (phase == 0 ? 1.0 : 1.03))
                }
            }
        } animation: { _ in
            .easeInOut(duration: 1.2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLocked)
    }
}

private enum FocusCorner: CaseIterable { case tl, tr, bl, br }

private struct CornerBracketShape: Shape {
    let corner: FocusCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let len: CGFloat = 28
        switch corner {
        case .tl:
            path.move(to: CGPoint(x: 0, y: len))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: len, y: 0))
        case .tr:
            path.move(to: CGPoint(x: rect.width - len, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: len))
        case .bl:
            path.move(to: CGPoint(x: 0, y: rect.height - len))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: len, y: rect.height))
        case .br:
            path.move(to: CGPoint(x: rect.width - len, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - len))
        }
        return path
    }
}   
