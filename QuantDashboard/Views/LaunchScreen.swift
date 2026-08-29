// ============================================================
// LaunchScreen.swift
// QuantDashboard - 启动画面
// ============================================================

import SwiftUI

// MARK: - 启动画面视图
struct LaunchScreenView: View {

    @State private var isAnimating = false
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            LiquidGlassTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Logo
                ZStack {
                    Circle()
                        .stroke(
                            LiquidGlassTheme.radarGradient(for: 50),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: isAnimating)

                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                }

                VStack(spacing: 8) {
                    Text("QuantDashboard")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(LiquidGlassTheme.primaryText)

                    Text("量化交易看板")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                }

                Text("Liquid Glass Edition")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1
            }
            isAnimating = true
        }
    }
}

// MARK: - Preview
#Preview {
    LaunchScreenView()
}
