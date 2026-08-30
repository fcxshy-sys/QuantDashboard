import SwiftUI

struct PerformanceTrackerView: View {
    @StateObject private var journal = TradeJournalManager.shared
    @StateObject private var statsManager = SignalStatsManager.shared
    @State private var selectedPeriod: Period = .all

    enum Period: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case all = "全部"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("绩效追踪")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 4)

                periodPicker

                overviewCards

                winRateChart

                equityCurve

                statsBreakdown
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(Period.allCases, id: \.self) { p in
                Button { selectedPeriod = p } label: {
                    Text(p.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selectedPeriod == p ? .white : LiquidGlassTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selectedPeriod == p ? LiquidGlassTheme.neutralAccent : Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var overviewCards: some View {
        HStack(spacing: 10) {
            miniCard(value: "\(filteredRecords.count)", label: "总交易", color: LiquidGlassTheme.primaryText)
            miniCard(value: String(format: "%.0f%%", winRate), label: "胜率", color: winRate >= 50 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
            miniCard(value: String(format: "$%.0f", totalPnL), label: "总盈亏", color: totalPnL >= 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
        }
    }

    private func miniCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private var winRateChart: some View {
        GlassCard(title: "胜率分布", icon: "chart.pie") {
            if filteredRecords.isEmpty {
                Text("暂无交易数据")
                    .font(.system(size: 12))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                let wins = filteredRecords.filter { ($0.profitLoss ?? 0) > 0 }.count
                let losses = filteredRecords.count - wins
                let winPct = Double(wins) / Double(filteredRecords.count)
                let lossPct = Double(losses) / Double(filteredRecords.count)

                VStack(spacing: 10) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(LiquidGlassTheme.bullishAccent)
                                .frame(width: geo.size.width * winPct)
                            Rectangle()
                                .fill(LiquidGlassTheme.bearishAccent)
                                .frame(width: geo.size.width * lossPct)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 12)

                    HStack {
                        HStack(spacing: 4) {
                            Circle().fill(LiquidGlassTheme.bullishAccent).frame(width: 8, height: 8)
                            Text("盈利 \(wins)")
                                .font(.system(size: 11))
                                .foregroundStyle(LiquidGlassTheme.secondaryText)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(LiquidGlassTheme.bearishAccent).frame(width: 8, height: 8)
                            Text("亏损 \(losses)")
                                .font(.system(size: 11))
                                .foregroundStyle(LiquidGlassTheme.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private var equityCurve: some View {
        GlassCard(title: "收益曲线", icon: "chart.line.uptrend.xyaxis") {
            let closedRecords = filteredRecords.filter { $0.exitPrice != nil }
            guard !closedRecords.isEmpty else {
                return AnyView(
                    Text("暂无平仓数据")
                        .font(.system(size: 12))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                )
            }

            var equity: [Double] = []
            var running = 10000.0
            for r in closedRecords {
                running += r.profitLoss ?? 0
                equity.append(running)
            }

            return AnyView(
                GeometryReader { geo in
                    let minV = equity.min() ?? 0
                    let maxV = equity.max() ?? 1
                    let range = maxV - minV

                    Canvas { context, size in
                        guard equity.count > 1 else { return }
                        let step = size.width / CGFloat(equity.count - 1)
                        var path = Path()
                        for (i, v) in equity.enumerated() {
                            guard v.isFinite else { continue }
                            let x = CGFloat(i) * step
                            let y = range > 0 ? size.height * (1 - CGFloat((v - minV) / range)) : size.height / 2
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(path, with: .color(LiquidGlassTheme.neutralAccent), lineWidth: 2)
                    }
                }
                .frame(height: 120)
            )
        }
    }

    private var statsBreakdown: some View {
        GlassCard(title: "信号统计", icon: "waveform") {
            if statsManager.stats.isEmpty {
                Text("运行指标后自动生成统计")
                    .font(.system(size: 12))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(statsManager.stats) { stat in
                        HStack {
                            Text(stat.indicatorName)
                                .font(.system(size: 12))
                                .foregroundStyle(LiquidGlassTheme.secondaryText)
                            Spacer()
                            HStack(spacing: 12) {
                                Text("\(stat.totalSignals)次")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                                Text(String(format: "%.0f%%", stat.accuracy))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(stat.accuracy > 50 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredRecords: [TradeRecord] {
        let cal = Calendar.current
        switch selectedPeriod {
        case .week:
            return journal.records.filter { cal.isDate($0.entryDate, equalTo: Date(), toGranularity: .weekOfYear) }
        case .month:
            return journal.records.filter { cal.isDate($0.entryDate, equalTo: Date(), toGranularity: .month) }
        case .all:
            return journal.records
        }
    }

    private var winRate: Double {
        let closed = filteredRecords.filter { $0.exitPrice != nil }
        guard !closed.isEmpty else { return 0 }
        let wins = closed.filter { ($0.profitLoss ?? 0) > 0 }.count
        return Double(wins) / Double(closed.count) * 100
    }

    private var totalPnL: Double {
        filteredRecords.compactMap { $0.profitLoss }.reduce(0, +)
    }
}
