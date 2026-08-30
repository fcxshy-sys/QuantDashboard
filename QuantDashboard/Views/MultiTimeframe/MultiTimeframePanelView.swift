import SwiftUI

struct MultiTimeframePanelView: View {
    @ObservedObject var indicatorVM: IndicatorViewModel
    @ObservedObject var marketVM: MarketViewModel
    
    private let timeframes: [KLineInterval] = [.m1, .m15, .h1, .h4]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("多周期联动")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Text("\(marketVM.currentAsset.rawValue)")
                        .font(.system(size: 12))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
                .padding(.horizontal, 4)
                
                ForEach(1...5, id: \.self) { index in
                    GlassCard(title: "M\(index) \(indicatorVM.result(for: index)?.indicatorName ?? "指标\(index)")", icon: "waveform") {
                        HStack(spacing: 4) {
                            ForEach(timeframes, id: \.self) { tf in
                                VStack(spacing: 4) {
                                    Text(tf.displayName)
                                        .font(.system(size: 9))
                                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                                    signalBadge(for: tf)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
               共振统计卡片
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    @ViewBuilder
    private func signalBadge(for interval: KLineInterval) -> some View {
        let score = simulateMFScore(for: interval, index: 0)
        if score > 30 {
            Text("多")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LiquidGlassTheme.bullishAccent)
                .frame(width: 32, height: 22)
                .background(Capsule().fill(LiquidGlassTheme.bullishAccent.opacity(0.15)))
        } else if score < -30 {
            Text("空")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LiquidGlassTheme.bearishAccent)
                .frame(width: 32, height: 22)
                .background(Capsule().fill(LiquidGlassTheme.bearishAccent.opacity(0.15)))
        } else {
            Text("中")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LiquidGlassTheme.neutralAccent)
                .frame(width: 32, height: 22)
                .background(Capsule().fill(LiquidGlassTheme.neutralAccent.opacity(0.1)))
        }
    }
    
    private func simulateMFScore(for interval: KLineInterval, index: Int) -> Double {
        let ratio = Double(arc4random_uniform(100)) / 100.0
        return (ratio - 0.5) * 200
    }
    
    private var 共振统计卡片: some View {
        GlassCard(title: "多周期共振", icon: "arrow.triangle.2.circlepath") {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    resonanceStat(label: "多头共振", count: 2, color: LiquidGlassTheme.bullishAccent)
                    resonanceStat(label: "空头共振", count: 1, color: LiquidGlassTheme.bearishAccent)
                    resonanceStat(label: "无共振", count: 2, color: LiquidGlassTheme.neutralAccent)
                }
            }
        }
    }
    
    private func resonanceStat(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
