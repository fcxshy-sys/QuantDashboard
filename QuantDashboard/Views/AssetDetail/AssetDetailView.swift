import SwiftUI

struct AssetDetailView: View {
    @ObservedObject var marketVM: MarketViewModel
    @ObservedObject var indicatorVM: IndicatorViewModel
    let asset: TradeAsset

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Circle()
                        .fill(asset.themeColor)
                        .frame(width: 12, height: 12)
                    Text(asset.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 4)

                priceCard
                performanceCard
                indicatorSummary
                marketInfoCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var priceCard: some View {
        GlassCard(title: "当前价格", icon: "dollarsign.circle") {
            VStack(spacing: 8) {
                Text(marketVM.formattedPrice)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(LiquidGlassTheme.primaryText)

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("24H 涨跌")
                            .font(.system(size: 10))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                        Text(marketVM.formattedChange)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(marketVM.priceChangePercent24h >= 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                    }
                    VStack(spacing: 2) {
                        Text("24H 最高")
                            .font(.system(size: 10))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                        Text(String(format: "$%.2f", marketVM.high24h))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(LiquidGlassTheme.primaryText)
                    }
                    VStack(spacing: 2) {
                        Text("24H 最低")
                            .font(.system(size: 10))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                        Text(String(format: "$%.2f", marketVM.low24h))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(LiquidGlassTheme.primaryText)
                    }
                }

                priceRangeBar
            }
        }
    }

    private var priceRangeBar: some View {
        GeometryReader { geo in
            let range = marketVM.high24h - marketVM.low24h
            let position = range > 0 ? (marketVM.latestPrice - marketVM.low24h) / range : 0.5
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                    .frame(height: 4)
                Capsule()
                    .fill(LiquidGlassTheme.neutralAccent)
                    .frame(width: geo.size.width * max(0, min(1, position)), height: 4)
                Circle()
                    .fill(LiquidGlassTheme.primaryText)
                    .frame(width: 8, height: 8)
                    .offset(x: geo.size.width * max(0, min(1, position)) - 4)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 4)
    }

    private var performanceCard: some View {
        GlassCard(title: "资产表现", icon: "chart.bar.fill") {
            HStack(spacing: 12) {
                statBox("成交量", marketVM.formattedVolume, LiquidGlassTheme.neutralAccent)
                statBox("延迟", "\(Int(marketVM.latency))ms", marketVM.latency < 100 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                statBox("更新", timeAgo, LiquidGlassTheme.tertiaryText)
            }
        }
    }

    private func statBox(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var indicatorSummary: some View {
        GlassCard(title: "指标信号", icon: "waveform.path.ecg") {
            VStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    if let result = indicatorVM.result(for: index) {
                        HStack {
                            Text("M\(index)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(LiquidGlassTheme.tertiaryText)
                                .frame(width: 28)
                            Text(result.indicatorName)
                                .font(.system(size: 12))
                                .foregroundStyle(LiquidGlassTheme.secondaryText)
                            Spacer()
                            Text(result.signal.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(result.signal == .bullish ? LiquidGlassTheme.bullishAccent : result.signal == .bearish ? LiquidGlassTheme.bearishAccent : LiquidGlassTheme.neutralAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill((result.signal == .bullish ? LiquidGlassTheme.bullishAccent : result.signal == .bearish ? LiquidGlassTheme.bearishAccent : LiquidGlassTheme.neutralAccent).opacity(0.12)))
                        }
                    }
                }
            }
        }
    }

    private var marketInfoCard: some View {
        GlassCard(title: "市场信息", icon: "info.circle") {
            VStack(spacing: 6) {
                infoRow("资产类型", asset.assetType.rawValue)
                infoRow("交易所", "Gate.io")
                if let gateName = asset.gateIOName {
                    infoRow("交易对", gateName)
                } else {
                    infoRow("交易对", "非加密货币")
                }
                infoRow("简称", asset.shortName)
                infoRow("数据源", marketVM.connectionStatus)
                infoRow("最后更新", marketVM.lastUpdateTime.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LiquidGlassTheme.primaryText)
        }
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(marketVM.lastUpdateTime)
        if interval < 60 { return "\(Int(interval))秒前" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        return "\(Int(interval / 3600))小时前"
    }
}
