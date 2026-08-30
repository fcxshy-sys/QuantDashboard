// ============================================================
// IndicatorPanelView.swift
// QuantDashboard - 指标面板视图（副图折叠面板）
// ============================================================

import SwiftUI

// MARK: - 指标面板视图
/// 五个指标的副图曲线、柱状图渲染，支持独立显隐与滑动切换
struct IndicatorPanelView: View {

    @ObservedObject var indicatorVM: IndicatorViewModel

    @State private var expandedIndex: Int? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // 标题
                HStack {
                    Text("指标面板")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Text("5 个核心指标")
                        .font(.system(size: 12))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
                .padding(.horizontal, 4)

                // 指标列表
                ForEach(1...5, id: \.self) { index in
                    IndicatorPanelCard(
                        index: index,
                        result: indicatorVM.result(for: index),
                        timeSeries: indicatorVM.timeSeries(for: index),
                        isExpanded: expandedIndex == index,
                        onToggle: {
                            withAnimation(.spring(response: 0.4)) {
                                if expandedIndex == index {
                                    expandedIndex = nil
                                } else {
                                    expandedIndex = index
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - 指标面板卡片
struct IndicatorPanelCard: View {

    let index: Int
    let result: IndicatorResult?
    let timeSeries: [IndicatorTimePoint]
    let isExpanded: Bool
    let onToggle: () -> Void

    private var direction: SignalDirection {
        result?.signal ?? .neutral
    }

    var body: some View {
        GlassCard(direction: direction) {
            VStack(spacing: 0) {
                // 摘要行（始终可见）
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        // 指标编号
                        ZStack {
                            Circle()
                                .fill(directionColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Text("M\(index)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(directionColor)
                        }

                        // 指标名称与值
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result?.indicatorName ?? "指标 \(index)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LiquidGlassTheme.primaryText)
                            Text(result?.description ?? "等待数据...")
                                .font(.system(size: 11))
                                .foregroundStyle(LiquidGlassTheme.tertiaryText)
                                .lineLimit(1)
                        }

                        Spacer()

                        // 当前值
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(String(format: "%.2f", result?.value ?? 0))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(LiquidGlassTheme.primaryText)
                            directionBadge
                        }

                        // 展开箭头
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                // 展开的详情区域
                if isExpanded {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.top, 8)

                    expandedContent
                        .padding(.top, 12)
                }
            }
        }
    }

    // MARK: - 展开内容
    private var expandedContent: some View {
        VStack(spacing: 12) {
            // 指标曲线图
            if !timeSeries.isEmpty {
                GeometryReader { geo in
                    let values = timeSeries.map(\.mainValue)
                    let minVal = values.min() ?? 0
                    let maxVal = values.max() ?? 1
                    let range = maxVal - minVal

                    Canvas { context, size in
                        guard values.count > 1 else { return }
                        let stepX = size.width / CGFloat(values.count - 1)

                        // 主值曲线
                        var mainPath = Path()
                        for (i, val) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = range > 0
                                ? size.height * (1 - CGFloat((val - minVal) / range))
                                : size.height / 2
                            if i == 0 { mainPath.move(to: CGPoint(x: x, y: y)) }
                            else { mainPath.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(
                            mainPath,
                            with: .color(directionColor),
                            lineWidth: 1.5
                        )

                        // 辅助值曲线
                        let secValues = timeSeries.compactMap(\.secondaryValue)
                        if !secValues.isEmpty {
                            var secPath = Path()
                            let secMin = secValues.min() ?? 0
                            let secMax = secValues.max() ?? 1
                            let secRange = secMax - secMin
                            for (i, val) in secValues.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = secRange > 0
                                    ? size.height * (1 - CGFloat((val - secMin) / secRange))
                                    : size.height / 2
                                if i == 0 { secPath.move(to: CGPoint(x: x, y: y)) }
                                else { secPath.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            context.stroke(
                                secPath,
                                with: .color(LiquidGlassTheme.neutralAccent.opacity(0.6)),
                                lineWidth: 1
                            )
                        }
                    }
                }
                .frame(height: 120)
            }

            // 参数信息
            HStack(spacing: 12) {
                paramItem(label: "信号", value: direction.rawValue)
                paramItem(label: "强度", value: result?.strength.displayName ?? "-")
                paramItem(label: "值", value: String(format: "%.4f", result?.value ?? 0))
            }
            if let sec = result?.secondaryValue {
                HStack(spacing: 12) {
                    paramItem(label: "辅助值", value: String(format: "%.4f", sec))
                    if let ter = result?.tertiaryValue {
                        paramItem(label: "第三值", value: String(format: "%.4f", ter))
                    }
                    paramItem(label: "时间", value: result?.timestamp.formatted(date: .omitted, time: .shortened) ?? "-")
                }
            }
        }
    }

    private func paramItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var directionColor: Color {
        switch direction {
        case .bullish: return LiquidGlassTheme.bullishAccent
        case .bearish: return LiquidGlassTheme.bearishAccent
        case .neutral: return LiquidGlassTheme.neutralAccent
        }
    }

    private var directionBadge: some View {
        Text(direction.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(directionColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(directionColor.opacity(0.15)))
    }
}
