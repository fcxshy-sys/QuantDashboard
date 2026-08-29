// ============================================================
// LiquidGlassModifier.swift
// QuantDashboard - 液态毛玻璃 ViewModifier 核心组件
// ============================================================

import SwiftUI

// MARK: - 液态玻璃修饰器
/// 一键为任意 View 添加 Liquid Glass 液态毛玻璃质感
struct LiquidGlassModifier: ViewModifier {

    // MARK: - 配置参数
    var cornerRadius: CGFloat = 20
    var fillOpacity: Double = 0.05
    var strokeOpacity: Double = 0.12
    var blurRadius: CGFloat = 20
    var glowColor: Color = .clear
    var glowIntensity: Double = 0
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1. 超薄材质底色
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // 2. 半透明填充
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(fillOpacity))

                    // 3. 多空动态流光（背景呼吸光斑）
                    if glowIntensity > 0 {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(glowColor.opacity(glowIntensity * 0.1))
                            .blur(radius: 30)
                    }

                    // 4. 顶部高光折射（模拟光源）
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LiquidGlassTheme.refractionGradient)
                        .frame(height: cornerRadius * 2)
                        .clipped()

                    // 5. 内发光
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            Color.white.opacity(isHighlighted ? 0.20 : 0.05),
                            lineWidth: 1
                        )
                        .blur(radius: 2)
                }
            )
            // 6. 液态边缘折射描边
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LiquidGlassTheme.liquidBorderGradient,
                        lineWidth: isHighlighted ? 1.5 : 0.8
                    )
            )
            // 7. 悬浮阴影
            .shadow(
                color: LiquidGlassTheme.cardShadow.opacity(0.4),
                radius: LiquidGlassTheme.cardShadowRadius,
                x: 0,
                y: LiquidGlassTheme.cardShadowY
            )
            // 8. 高亮时额外外发光
            .shadow(
                color: glowColor.opacity(glowIntensity * 0.3),
                radius: glowIntensity > 0 ? 15 : 0,
                x: 0,
                y: 0
            )
    }
}

// MARK: - View 扩展：一键应用液态玻璃
extension View {
    /// 一键应用液态毛玻璃效果
    func liquidGlass(
        cornerRadius: CGFloat = 20,
        fillOpacity: Double = 0.05,
        strokeOpacity: Double = 0.12,
        glowColor: Color = .clear,
        glowIntensity: Double = 0,
        isHighlighted: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            fillOpacity: fillOpacity,
            strokeOpacity: strokeOpacity,
            glowColor: glowColor,
            glowIntensity: glowIntensity,
            isHighlighted: isHighlighted
        ))
    }

    /// 快速应用液态玻璃（根据多空状态自动着色）
    func liquidGlassForSignal(direction: SignalDirection, isActive: Bool = true) -> some View {
        let color: Color
        let intensity: Double
        switch direction {
        case .bullish:
            color = LiquidGlassTheme.bullishGlow
            intensity = isActive ? 1.0 : 0.3
        case .bearish:
            color = LiquidGlassTheme.bearishGlow
            intensity = isActive ? 1.0 : 0.3
        case .neutral:
            color = LiquidGlassTheme.neutralGlow
            intensity = isActive ? 0.6 : 0.2
        }
        return modifier(LiquidGlassModifier(
            glowColor: color,
            glowIntensity: intensity,
            isHighlighted: isActive
        ))
    }
}
