import SwiftUI

struct BacktestView: View {
    @ObservedObject var marketVM: MarketViewModel
    @ObservedObject var indicatorVM: IndicatorViewModel
    
    @State private var result: BacktestResult?
    @State private var isRunning = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("策略回测")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                GlassCard(title: "回测设置", icon: "gearshape") {
                    VStack(spacing: 10) {
                        HStack {
                            Text("资产")
                                .foregroundStyle(LiquidGlassTheme.secondaryText)
                            Spacer()
                            Text(marketVM.currentAsset.rawValue)
                                .foregroundStyle(LiquidGlassTheme.primaryText)
                        }
                        HStack {
                            Text("周期")
                                .foregroundStyle(LiquidGlassTheme.secondaryText)
                            Spacer()
                            Text(marketVM.currentInterval.displayName)
                                .foregroundStyle(LiquidGlassTheme.primaryText)
                        }
                        HStack {
                            Text("数据量")
                                .foregroundStyle(LiquidGlassTheme.secondaryText)
                            Spacer()
                            Text("\(marketVM.candles.count) 根K线")
                                .foregroundStyle(LiquidGlassTheme.primaryText)
                        }
                        
                        Button(isRunning ? "回测中..." : "开始回测") {
                            runBacktest()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(isRunning ? LiquidGlassTheme.neutralAccent.opacity(0.5) : LiquidGlassTheme.neutralAccent))
                        .disabled(isRunning || marketVM.candles.count < 120)
                    }
                }
                
                if let r = result { resultCard(r) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    private func runBacktest() {
        isRunning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let r = BacktestEngine.run(
                candles: marketVM.candles, asset: marketVM.currentAsset,
                interval: marketVM.currentInterval, configs: indicatorVM.configs
            )
            DispatchQueue.main.async { result = r; isRunning = false }
        }
    }
    
    private func resultCard(_ r: BacktestResult) -> some View {
        GlassCard(title: "回测结果", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 10) {
                statRow("总交易数", "\(r.totalTrades)")
                statRow("胜率", String(format: "%.1f%%", r.winRate))
                statRow("总收益", String(format: "%+.1f%%", r.totalReturn))
                statRow("最大回撤", String(format: "%.1f%%", r.maxDrawdown))
                statRow("夏普比率", String(format: "%.2f", r.sharpeRatio))
                
                if !r.equityCurve.isEmpty {
                    equityChart(r.equityCurve)
                }
                
                if !r.trades.isEmpty {
                    Text("最近交易")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(r.trades.suffix(5)) { trade in
                        HStack {
                            Text(trade.side == .long ? "多" : "空")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(trade.side == .long ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                            Text(String(format: "%.2f → %.2f", trade.entryPrice, trade.exitPrice))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(LiquidGlassTheme.primaryText)
                            Spacer()
                            Text(String(format: "%+.2f%%", trade.profitPercent))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(trade.profitPercent > 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                        }
                    }
                }
            }
        }
    }
    
    private func equityChart(_ curve: [Double]) -> some View {
        GeometryReader { geo in
            let minV = curve.min() ?? 0
            let maxV = curve.max() ?? 1
            let range = maxV - minV
            Canvas { context, size in
                guard curve.count > 1 else { return }
                let step = size.width / CGFloat(curve.count - 1)
                var path = Path()
                for (i, v) in curve.enumerated() {
                    let x = CGFloat(i) * step
                    let y = range > 0 ? size.height * (1 - CGFloat((v - minV) / range)) : size.height / 2
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(LiquidGlassTheme.neutralAccent), lineWidth: 1.5)
            }
        }
        .frame(height: 100)
    }
    
    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(LiquidGlassTheme.primaryText)
        }
    }
}
