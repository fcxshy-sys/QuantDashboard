// ============================================================
// RadarView.swift
// QuantDashboard - 综合雷达评分仪表盘视图
// ============================================================

import SwiftUI

// MARK: - 雷达仪表盘（Hero Card）
/// 液态水晶圆环 + 动态流光评分，高亮展示 5 个指标的多空综合得分
struct RadarView: View {

    let score: RadarScore?
    let asset: TradeAsset

    @State private var animationProgress: Double = 0
    @State private var ringRotation: Double = 0

    var body: some View {
        GlassCard(title: "综合雷达", icon: "scope", direction: score?.consensusDirection ?? .neutral) {
            VStack(spacing: 16) {
                // 圆环评分
                ZStack {
                    // 背景环
                    Circle()
                        .stroke(
                            Color.white.opacity(0.06),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )

                    // 动态流光进度环
                    Circle()
                        .trim(from: 0, to: animationProgress)
                        .stroke(
                            LiquidGlassTheme.radarGradient(for: score?.score ?? 0),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .rotationEffect(.degrees(ringRotation))
                        .animation(.easeInOut(duration: 1.5), value: animationProgress)

                    // 内发光环
                    Circle()
                        .stroke(
                            LiquidGlassTheme.radarGradient(for: score?.score ?? 0),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .blur(radius: 8)
                        .opacity(0.5)

                    // 中心数值
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", score?.score ?? 0))
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundStyle(scoreColor)
                            .contentTransition(.numericText())

                        Text(score?.scoreLevel ?? "计算中")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LiquidGlassTheme.secondaryText)

                        Text(asset.shortName)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(asset.themeColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(asset.themeColor.opacity(0.15)))
                    }
                }
                .frame(width: 180, height: 180)

                // 共振状态
                HStack(spacing: 12) {
                    GlassCapsule(
                        text: "\(score?.consensusCount ?? 0)/5 共振",
                        color: (score?.isStrongSignal ?? false)
                            ? (score?.consensusDirection == .bullish
                                ? LiquidGlassTheme.bullishAccent
                                : LiquidGlassTheme.bearishAccent)
                            : LiquidGlassTheme.neutralAccent
                    )

                    if score?.isStrongSignal == true {
                        GlassCapsule(
                            text: "⚡ 强信号",
                            color: .orange
                        )
                    }

                    Spacer()
                }

                // 建议文案
                if let advisory = score?.advisory {
                    Text(advisory)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                // 5 个指标独立得分条
                if let scores = score?.indicatorScores {
                    VStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { index in
                            IndicatorScoreBar(
                                index: index,
                                score: scores[index] ?? 0
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: score?.score) { _ in
            startAnimations()
        }
    }

    private var scoreColor: Color {
        guard let score = score?.score else {
            return LiquidGlassTheme.neutralAccent
        }
        if score > 30 { return LiquidGlassTheme.bullishAccent }
        if score < -30 { return LiquidGlassTheme.bearishAccent }
        return LiquidGlassTheme.neutralAccent
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.5)) {
            animationProgress = (score?.normalizedScore ?? 50) / 100.0
        }
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }
}

// MARK: - 单个指标得分条
struct IndicatorScoreBar: View {

    let index: Int
    let score: Double

    private var normalizedPosition: Double {
        let pos = (score + 100) / 200
        return pos.isFinite ? min(max(pos, 0), 1) : 0.5
    }

    private var barColor: Color {
        if score > 20 { return LiquidGlassTheme.bullishAccent }
        if score < -20 { return LiquidGlassTheme.bearishAccent }
        return LiquidGlassTheme.neutralAccent
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("M\(index)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
                .frame(width: 24)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))

                    // 中性区域标记
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 4, height: geo.size.height)
                        .offset(x: geo.size.width * 0.5 - 2)

                    // 得分指示器
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(
                            width: max(4, geo.size.width * abs(normalizedPosition - 0.5)),
                            height: geo.size.height
                        )
                        .offset(x: normalizedPosition > 0.5
                            ? geo.size.width * 0.5
                            : geo.size.width * normalizedPosition)
                }
            }
            .frame(height: 6)

            Text(String(format: "%.0f", score.isFinite ? score : 0))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(barColor)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
