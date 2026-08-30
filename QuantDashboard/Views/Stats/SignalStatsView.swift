import SwiftUI

struct SignalStatsView: View {
    @StateObject private var statsManager = SignalStatsManager.shared
    @ObservedObject var indicatorVM: IndicatorViewModel
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("信号统计")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Button("重置") { statsManager.resetStats() }
                        .font(.system(size: 12))
                        .foregroundStyle(LiquidGlassTheme.bearishAccent)
                }
                .padding(.horizontal, 4)
                
                if statsManager.stats.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 40))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                        Text("暂无统计数据")
                            .font(.system(size: 14))
                            .foregroundStyle(LiquidGlassTheme.secondaryText)
                        Text("运行一段时间后自动生成")
                            .font(.system(size: 12))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    overallStatsCard
                    
                    ForEach(statsManager.stats) { stat in
                        statCard(stat)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    private var overallStatsCard: some View {
        GlassCard(title: "综合统计", icon: "chart.pie") {
            let total = statsManager.stats.reduce(0) { $0 + $1.totalSignals }
            let correct = statsManager.stats.reduce(0) { $0 + $1.correctPredictions }
            let avgAcc = total > 0 ? Double(correct) / Double(total) * 100 : 0
            
            HStack(spacing: 16) {
                statCircle(value: String(format: "%.0f", avgAcc), label: "准确率%", color: LiquidGlassTheme.neutralAccent)
                statCircle(value: "\(total)", label: "总信号", color: LiquidGlassTheme.bullishAccent)
                statCircle(value: "\(correct)", label: "正确", color: LiquidGlassTheme.bearishAccent)
            }
        }
    }
    
    private func statCircle(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func statCard(_ stat: SignalStats) -> some View {
        GlassCard(title: stat.indicatorName, icon: "waveform") {
            VStack(spacing: 8) {
                HStack {
                    Text("信号总数: \(stat.totalSignals)")
                        .font(.system(size: 11))
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                    Spacer()
                    Text("准确率: \(String(format: "%.1f%%", stat.accuracy))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(stat.accuracy > 50 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                }
                HStack {
                    Text("多头: \(stat.bullishSignals)")
                        .font(.system(size: 11))
                        .foregroundStyle(LiquidGlassTheme.bullishAccent)
                    Spacer()
                    Text("空头: \(stat.bearishSignals)")
                        .font(.system(size: 11))
                        .foregroundStyle(LiquidGlassTheme.bearishAccent)
                    Spacer()
                    Text("正确: \(stat.correctPredictions)")
                        .font(.system(size: 11))
                        .foregroundStyle(LiquidGlassTheme.neutralAccent)
                }
            }
        }
    }
}
