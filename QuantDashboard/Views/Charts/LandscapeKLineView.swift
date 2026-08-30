import SwiftUI

struct LandscapeKLineView: View {
    @ObservedObject var marketVM: MarketViewModel
    @ObservedObject var indicatorVM: IndicatorViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text(marketVM.currentAsset.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text(marketVM.formattedPrice)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(marketVM.formattedChange)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(marketVM.priceChange24h >= 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    landscapeChart
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                sidePanel
                    .frame(width: 280)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
    
    private var landscapeChart: some View {
        let candles = marketVM.candles
        return Canvas { context, size in
            guard candles.count > 1 else { return }
            let priceMin = candles.map(\.low).min() ?? 0
            let priceMax = candles.map(\.high).max() ?? 1
            let priceRange = priceMax - priceMin
            let step = size.width / CGFloat(candles.count)
            let bw = max(step * 0.7, 1)
            
            for (i, c) in candles.enumerated() {
                let x = CGFloat(i) * step + step / 2
                func y(_ p: Double) -> CGFloat {
                    priceRange > 0 ? size.height * (1 - CGFloat((p - priceMin) / priceRange)) : size.height / 2
                }
                let color: Color = c.isBullish ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent
                
                var shadow = Path()
                shadow.move(to: CGPoint(x: x, y: y(c.high)))
                shadow.addLine(to: CGPoint(x: x, y: y(c.low)))
                context.stroke(shadow, with: .color(color.opacity(0.5)), lineWidth: 0.5)
                
                let top = y(max(c.open, c.close))
                let bot = y(min(c.open, c.close))
                let rect = CGRect(x: x - bw / 2, y: top, width: bw, height: max(bot - top, 1))
                context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(color))
            }
        }
        .padding(8)
    }
    
    private var sidePanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                Text("指标概览")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(1...5, id: \.self) { index in
                    if let result = indicatorVM.result(for: index) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("M\(index)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.5))
                                Spacer()
                                Text(result.signal.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(result.signal == .bullish ? LiquidGlassTheme.bullishAccent : result.signal == .bearish ? LiquidGlassTheme.bearishAccent : .white.opacity(0.5))
                            }
                            Text(result.indicatorName)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                            Text(result.description)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    }
                }
            }
            .padding(12)
        }
        .background(Color.white.opacity(0.03))
    }
}
