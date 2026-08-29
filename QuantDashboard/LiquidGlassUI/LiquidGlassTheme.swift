// ============================================================
// LiquidGlassTheme.swift
// QuantDashboard - 液态毛玻璃设计系统主题配置
// ============================================================

import SwiftUI

// MARK: - 液态玻璃主题
struct LiquidGlassTheme {

    // MARK: - 背景层级
    static var isDark: Bool { ThemeManager.shared.isDarkMode }

    static var backgroundGradient: LinearGradient {
        if isDark {
            return LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color(red: 0.05, green: 0.03, blue: 0.08),
                    Color(red: 0.01, green: 0.01, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.95, blue: 0.97),
                    Color(red: 0.90, green: 0.92, blue: 0.96),
                    Color(red: 0.93, green: 0.94, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static var secondaryBackground: Color {
        isDark ? Color.black.opacity(0.6) : Color.white.opacity(0.6)
    }

    // MARK: - 玻璃材质颜色
    static var glassFill: Color {
        isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    static var glassStroke: Color {
        isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    // MARK: - 液态边缘折射光泽
    static var refractionGradient: LinearGradient {
        if isDark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.20),
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.60),
                    Color.white.opacity(0.20),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static var liquidBorderGradient: LinearGradient {
        if isDark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.05),
                    Color.white.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - 多空动态流光颜色
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

    static let neutralGlow = Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.12)
    static let neutralAccent = Color(red: 0.3, green: 0.5, blue: 0.9)

    // MARK: - 文字颜色
    static var primaryText: Color { isDark ? Color.white : Color.black }
    static var secondaryText: Color { isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.6) }
    static var tertiaryText: Color { isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35) }
    static var mutedText: Color { isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.2) }

    // MARK: - 阴影参数
    static var cardShadow: Color { isDark ? Color.black.opacity(0.5) : Color.gray.opacity(0.3) }
    static let cardShadowRadius: CGFloat = 20
    static let cardShadowY: CGFloat = 8

    static var innerGlow: Color { isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03) }

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
        case .btcUSDT: return Color(red: 0.99, green: 0.60, blue: 0.15)
        case .ethUSDT: return Color(red: 0.40, green: 0.45, blue: 0.90)
        case .solUSDT: return Color(red: 0.80, green: 0.15, blue: 0.90)
        case .bnbUSDT: return Color(red: 0.95, green: 0.75, blue: 0.15)
        case .xrpUSDT: return Color(red: 0.20, green: 0.40, blue: 0.90)
        case .xauUSD:  return Color(red: 1.00, green: 0.82, blue: 0.00)
        }
    }
}
