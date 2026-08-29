// ============================================================
// GlassCard.swift
// QuantDashboard - 液态水晶玻璃卡片组件
// ============================================================

import SwiftUI

// MARK: - 液态玻璃卡片
/// 通用的液态毛玻璃容器卡片，支持动态流光与标题
struct GlassCard<Content: View>: View {

    let title: String?
    let icon: String?
    let direction: SignalDirection
    let content: () -> Content

    @State private var breathPhase: Bool = false

    init(title: String? = nil, icon: String? = nil,
         direction: SignalDirection = .neutral,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.direction = direction
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            if let title = title {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(directionColor)
                    }
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }

            // 内容区
            content()
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .liquidGlass(
            cornerRadius: 20,
            glowColor: directionColor,
            glowIntensity: breathPhase ? 0.6 : 0.3,
            isHighlighted: direction != .neutral
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathPhase = true
            }
        }
    }

    private var directionColor: Color {
        switch direction {
        case .bullish: return LiquidGlassTheme.bullishAccent
        case .bearish: return LiquidGlassTheme.bearishAccent
        case .neutral: return LiquidGlassTheme.neutralAccent
        }
    }
}

// MARK: - 迷你玻璃按钮
struct GlassButton: View {

    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? LiquidGlassTheme.primaryText : LiquidGlassTheme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.10 : 0.03))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        Color.white.opacity(isSelected ? 0.20 : 0.08),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 玻璃胶囊标签
struct GlassCapsule: View {

    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(0.25), lineWidth: 0.5)
            )
    }
}
