// ============================================================
// LiquidGlassTheme.swift
// QuantDashboard - 液态毛玻璃设计系统主题配置
// ============================================================

import SwiftUI

// MARK: - 液态玻璃主题
/// 统一管理 Liquid Glass 设计系统的颜色、材质、阴影参数
struct LiquidGlassTheme {

    // MARK: - 背景层级
    /// 主背景：Ultra-Dark OLED 深邃渐变
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.02, blue: 0.05),
            Color(red: 0.05, green: 0.03, blue: 0.08),
            Color(red: 0.01, green: 0.01, blue: 0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 次级背景
    static let secondaryBackground = Color.black.opacity(0.6)

    // MARK: - 玻璃材质颜色
    /// 玻璃卡片填充色（超薄材质）
    static let glassFill = Color.white.opacity(0.05)
    static let glassFillHover = Color.white.opacity(0.08)
    static let glassStroke = Color.white.opacity(0.12)
    static let glassStrokeHighlight = Color.white.opacity(0.25)

    // MARK: - 液态边缘折射光泽
    /// 顶部高光渐变（模拟光源折射）
    static let refractionGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.20),
            Color.white.opacity(0.05),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 液态边缘描边渐变
    static let liquidBorderGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.30),
            Color.white.opacity(0.10),
            Color.white.opacity(0.05),
            Color.white.opacity(0.15)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 多空动态流光颜色
    /// 多头（看多）绿色流光
    static let bullishGlow = Color(red: 0.0, green: 0.85, blue: 0.60).opacity(0.15)
    static let bullishAccent = Color(red: 0.0, green: 0.85, blue: 0.60)
    static let bullishGradient = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.85, blue: 0.60).opacity(0.15),
            Color(red: 0.0, green: 0.85, blue: 0.60).opacity(0.03)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 空头（看空）红色流光
    static let bearishGlow = Color(red: 0.95, green: 0.25, blue: 0.30).opacity(0.15)
    static let bearishAccent = Color(red: 0.95, green: 0.25, blue: 0.30)
    static let bearishGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.25, blue: 0.30).opacity(0.15),
            Color(red: 0.95, green: 0.25, blue: 0.30).opacity(0.03)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 中性蓝色流光
    static let neutralGlow = Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.12)
    static let neutralAccent = Color(red: 0.3, green: 0.5, blue: 0.9)

    // MARK: - 文字颜色
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let tertiaryText = Color.white.opacity(0.35)
    static let mutedText = Color.white.opacity(0.2)

    // MARK: - 阴影参数
    static let cardShadow = Color.black.opacity(0.5)
    static let cardShadowRadius: CGFloat = 20
    static let cardShadowY: CGFloat = 8

    /// 内发光颜色
    static let innerGlow = Color.white.opacity(0.05)

    // MARK: - 评分环渐变
    static func radarGradient(for score: Double) -> AngularGradient {
        let colors: [Color]
        if score > 30 {
            colors = [
                Color(red: 0.0, green: 0.85, blue: 0.60),
                Color(red: 0.0, green: 0.70, blue: 0.50),
                Color(red: 0.0, green: 0.85, blue: 0.60)
            ]
        } else if score < -30 {
            colors = [
                Color(red: 0.95, green: 0.25, blue: 0.30),
                Color(red: 0.85, green: 0.20, blue: 0.25),
                Color(red: 0.95, green: 0.25, blue: 0.30)
            ]
        } else {
            colors = [
                Color(red: 0.3, green: 0.5, blue: 0.9),
                Color(red: 0.25, green: 0.4, blue: 0.8),
                Color(red: 0.3, green: 0.5, blue: 0.9)
            ]
        }
        return AngularGradient(
            gradient: Gradient(colors: colors),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }
}

// MARK: - 资产对应主题色
extension TradeAsset {
    var themeColor: Color {
        switch self {
        case .btcUSDT: return Color(red: 0.99, green: 0.60, blue: 0.15)  // 橙色
        case .ethUSDT: return Color(red: 0.40, green: 0.45, blue: 0.90)  // 蓝紫色
        case .solUSDT: return Color(red: 0.80, green: 0.15, blue: 0.90)  // 紫色
        case .bnbUSDT: return Color(red: 0.95, green: 0.75, blue: 0.15)  // 金黄色
        case .xrpUSDT: return Color(red: 0.20, green: 0.40, blue: 0.90)  // 蓝色
        case .xauUSD:  return Color(red: 1.00, green: 0.82, blue: 0.00)  // 金色
        }
    }
}
