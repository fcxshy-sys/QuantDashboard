// ============================================================
// DashboardView.swift
// QuantDashboard - 主看板视图
// ============================================================

import SwiftUI

// MARK: - 主看板视图
struct DashboardView: View {

    @ObservedObject var marketVM: MarketViewModel
    @ObservedObject var indicatorVM: IndicatorViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // 价格概览卡片
                priceOverviewCard

                // 综合雷达仪表盘（Hero Card）
                RadarView(
                    score: indicatorVM.radarScore,
                    asset: marketVM.currentAsset
                )

                // 24H 行情摘要
                ticker24hCard

                // 最近告警
                if !indicatorVM.alertHistory.isEmpty {
                    recentAlertsCard
                }

                // 5 指标概览网格
                indicatorOverviewGrid
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            marketVM.start()
        }
    }

    // MARK: - 价格概览卡片
    private var priceOverviewCard: some View {
        GlassCard(direction: marketVM.priceChange24h >= 0 ? .bullish : .bearish) {
            VStack(spacing: 12) {
                // 资产名
                HStack {
                    Text(marketVM.currentAsset.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                    Spacer()
                    Text(marketVM.formattedChange)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(marketVM.priceChange24h >= 0
                            ? LiquidGlassTheme.bullishAccent
                            : LiquidGlassTheme.bearishAccent)
                }

                // 当前价格
                Text(marketVM.formattedPrice)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: marketVM.latestPrice)

                // 24H 数据行
                HStack(spacing: 20) {
                    statItem(title: "24H最高", value: String(format: "%.2f", marketVM.high24h))
                    statItem(title: "24H最低", value: String(format: "%.2f", marketVM.low24h))
                    statItem(title: "24H量", value: marketVM.formattedVolume)
                }
            }
        }
    }

    // MARK: - 统计项
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 24H 行情摘要
    private var ticker24hCard: some View {
        GlassCard(title: "24H 行情", icon: "clock") {
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    tickerStat(label: "涨跌额",
                              value: String(format: "%.2f", marketVM.priceChange24h),
                              color: marketVM.priceChange24h >= 0
                                ? LiquidGlassTheme.bullishAccent
                                : LiquidGlassTheme.bearishAccent)
                    tickerStat(label: "涨跌幅",
                              value: marketVM.formattedChange,
                              color: marketVM.priceChange24h >= 0
                                ? LiquidGlassTheme.bullishAccent
                                : LiquidGlassTheme.bearishAccent)
                    tickerStat(label: "成交量",
                              value: marketVM.formattedVolume,
                              color: LiquidGlassTheme.neutralAccent)
                }
            }
        }
    }

    private func tickerStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 最近告警
    private var recentAlertsCard: some View {
        GlassCard(title: "最近告警", icon: "bell.fill",
                  direction: indicatorVM.alertHistory.first?.direction ?? .neutral) {
            ForEach(indicatorVM.alertHistory.prefix(3)) { alert in
                HStack(spacing: 10) {
                    Circle()
                        .fill(alert.direction == .bullish
                            ? LiquidGlassTheme.bullishAccent
                            : LiquidGlassTheme.bearishAccent)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.message)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LiquidGlassTheme.primaryText)
                            .lineLimit(2)
                        Text(formatAlertTime(alert.timestamp))
                            .font(.system(size: 10))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    }

                    Spacer()

                    GlassCapsule(
                        text: alert.strength.displayName,
                        color: alert.direction == .bullish
                            ? LiquidGlassTheme.bullishAccent
                            : LiquidGlassTheme.bearishAccent
                    )
                }
                if alert.id != indicatorVM.alertHistory.prefix(3).last?.id {
                    Divider()
                        .background(Color.white.opacity(0.06))
                }
            }
        }
    }

    private func formatAlertTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    // MARK: - 指标概览网格
    private var indicatorOverviewGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("指标概览")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LiquidGlassTheme.primaryText)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(1...5, id: \.self) { index in
                    IndicatorMiniCard(
                        index: index,
                        result: indicatorVM.result(for: index)
                    )
                }
            }
        }
    }
}

// MARK: - 指标迷你卡片
struct IndicatorMiniCard: View {

    let index: Int
    let result: IndicatorResult?

    private var direction: SignalDirection {
        result?.signal ?? .neutral
    }

    var body: some View {
        GlassCard(direction: direction) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("M\(index)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    Spacer()
                    directionBadge
                }

                Text(result?.indicatorName ?? "指标 \(index)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LiquidGlassTheme.primaryText)

                Text(String(format: "%.2f", result?.value ?? 0))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                    .contentTransition(.numericText())

                Text(result?.description ?? "等待数据...")
                    .font(.system(size: 10))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
    }

    private var directionBadge: some View {
        let color: Color
        let text: String
        switch direction {
        case .bullish:
            color = LiquidGlassTheme.bullishAccent
            text = "多"
        case .bearish:
            color = LiquidGlassTheme.bearishAccent
            text = "空"
        case .neutral:
            color = LiquidGlassTheme.neutralAccent
            text = "中"
        }
        return Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}
