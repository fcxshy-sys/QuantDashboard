import SwiftUI

struct ExportView: View {
    @StateObject private var journalManager = TradeJournalManager.shared
    @StateObject private var statsManager = SignalStatsManager.shared
    @State private var showShareSheet = false
    @State private var exportData: Data?
    @State private var exportType: ExportType = .tradeJournal

    enum ExportType: String, CaseIterable {
        case tradeJournal = "交易记录"
        case signalStats = "信号统计"
        case snapshots = "每日快照"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("数据导出")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 4)

                typeSelector

                previewCard

                exportButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var typeSelector: some View {
        VStack(spacing: 8) {
            ForEach(ExportType.allCases, id: \.self) { type in
                Button { exportType = type } label: {
                    GlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(type))
                                .font(.system(size: 20))
                                .foregroundStyle(exportType == type ? LiquidGlassTheme.neutralAccent : LiquidGlassTheme.tertiaryText)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LiquidGlassTheme.primaryText)
                                Text(countFor(type))
                                    .font(.system(size: 11))
                                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                            }
                            Spacer()
                            Image(systemName: exportType == type ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(exportType == type ? LiquidGlassTheme.neutralAccent : LiquidGlassTheme.tertiaryText)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewCard: some View {
        GlassCard(title: "数据预览", icon: "doc.text") {
            VStack(alignment: .leading, spacing: 6) {
                switch exportType {
                case .tradeJournal:
                    if journalManager.records.isEmpty {
                        emptyPreview("暂无交易记录")
                    } else {
                        ForEach(journalManager.records.prefix(5)) { record in
                            HStack {
                                Text(record.side == .long ? "多" : "空")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(record.side == .long ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                                Text(record.asset.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundStyle(LiquidGlassTheme.secondaryText)
                                Spacer()
                                if let pl = record.profitLossPercent {
                                    Text(String(format: "%+.2f%%", pl))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(pl > 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                                }
                            }
                            Divider().background(Color.white.opacity(0.04))
                        }
                    }
                case .signalStats:
                    if statsManager.stats.isEmpty {
                        emptyPreview("暂无统计数据")
                    } else {
                        ForEach(statsManager.stats) { stat in
                            HStack {
                                Text(stat.indicatorName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(LiquidGlassTheme.secondaryText)
                                Spacer()
                                Text(String(format: "%.1f%%", stat.accuracy))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(stat.accuracy > 50 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                            }
                        }
                    }
                case .snapshots:
                    if statsManager.snapshots.isEmpty {
                        emptyPreview("暂无快照数据")
                    } else {
                        ForEach(statsManager.snapshots.prefix(5)) { snap in
                            HStack {
                                Text(snap.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 11))
                                    .foregroundStyle(LiquidGlassTheme.secondaryText)
                                Spacer()
                                Text(snap.asset)
                                    .font(.system(size: 11))
                                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                                Text(String(format: "$%.2f", snap.price))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(LiquidGlassTheme.primaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyPreview(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(LiquidGlassTheme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    private var exportButton: some View {
        Button {
            exportToCSV()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("导出 CSV 文件")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(LiquidGlassTheme.neutralAccent))
        }
    }

    private func exportToCSV() {
        var csv = ""
        switch exportType {
        case .tradeJournal:
            csv = "资产,方向,入场价,出场价,数量,盈亏%,入场时间,备注\n"
            for r in journalManager.records {
                csv += "\(r.asset.rawValue),\(r.side.rawValue),\(r.entryPrice),\(r.exitPrice ?? 0),\(r.quantity),\(r.profitLossPercent ?? 0),\(r.entryDate),\(r.notes)\n"
            }
        case .signalStats:
            csv = "指标名称,总信号,多头,空头,正确,准确率%\n"
            for s in statsManager.stats {
                csv += "\(s.indicatorName),\(s.totalSignals),\(s.bullishSignals),\(s.bearishSignals),\(s.correctPredictions),\(String(format: "%.1f", s.accuracy))\n"
            }
        case .snapshots:
            csv = "日期,资产,价格,雷达评分\n"
            for s in statsManager.snapshots {
                csv += "\(s.date),\(s.asset),\(s.price),\(s.radarScore)\n"
            }
        }
        exportData = csv.data(using: .utf8)
        showShareSheet = true
    }

    private func iconFor(_ type: ExportType) -> String {
        switch type {
        case .tradeJournal: return "list.clipboard"
        case .signalStats: return "chart.pie"
        case .snapshots: return "camera.metering.center.weighted"
        }
    }

    private func countFor(_ type: ExportType) -> String {
        switch type {
        case .tradeJournal: return "\(journalManager.records.count) 条记录"
        case .signalStats: return "\(statsManager.stats.count) 个指标"
        case .snapshots: return "\(statsManager.snapshots.count) 个快照"
        }
    }
}
