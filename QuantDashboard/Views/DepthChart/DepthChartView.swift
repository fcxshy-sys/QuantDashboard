import SwiftUI

struct DepthChartView: View {
    let asset: TradeAsset
    
    @State private var bids: [(price: Double, amount: Double)] = []
    @State private var asks: [(price: Double, amount: Double)] = []
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("深度图")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Text(asset.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
                .padding(.horizontal, 4)
                
                GlassCard(title: "盘口", icon: "arrow.left.arrow.right") {
                    depthChartContent
                }
                
                orderBookList
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .onAppear { generateMockData() }
    }
    
    private var depthChartContent: some View {
        GeometryReader { geo in
            let size = geo.size
            let maxAmount = max(bids.map(\.amount).max() ?? 1, asks.map(\.amount).max() ?? 1)
            let midX = size.width / 2
            
            Canvas { context, canvasSize in
                for (i, bid) in bids.prefix(20).enumerated() {
                    let w = CGFloat(bid.amount / maxAmount) * midX
                    let y = size.height * CGFloat(i) / 20
                    let h = size.height / 20
                    let rect = CGRect(x: midX - w, y: y, width: w, height: h)
                    context.fill(Path(rect), with: .color(LiquidGlassTheme.bullishAccent.opacity(0.4)))
                }
                for (i, ask) in asks.prefix(20).enumerated() {
                    let w = CGFloat(ask.amount / maxAmount) * midX
                    let y = size.height * CGFloat(i) / 20
                    let h = size.height / 20
                    let rect = CGRect(x: midX, y: y, width: w, height: h)
                    context.fill(Path(rect), with: .color(LiquidGlassTheme.bearishAccent.opacity(0.4)))
                }
                
                var midPath = Path()
                midPath.move(to: CGPoint(x: midX, y: 0))
                midPath.addLine(to: CGPoint(x: midX, y: size.height))
                context.stroke(midPath, with: .color(Color.white.opacity(0.3)), lineWidth: 0.5)
            }
        }
        .frame(height: 200)
    }
    
    private var orderBookList: some View {
        GlassCard(title: "委托列表", icon: "list.bullet") {
            VStack(spacing: 0) {
                HStack {
                    Text("价格")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    Spacer()
                    Text("数量")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                ForEach(asks.prefix(5).reversed(), id: \.price) { ask in
                    orderRow(price: ask.price, amount: ask.amount, color: LiquidGlassTheme.bearishAccent)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                ForEach(bids.prefix(5), id: \.price) { bid in
                    orderRow(price: bid.price, amount: bid.amount, color: LiquidGlassTheme.bullishAccent)
                }
            }
        }
    }
    
    private func orderRow(price: Double, amount: Double, color: Color) -> some View {
        HStack {
            Text(String(format: "%.2f", price))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Spacer()
            Text(String(format: "%.4f", amount))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func generateMockData() {
        let basePrice = asset == .xauUSD ? 2400.0 : 60000.0
        bids = (0..<20).map { i in
            let p = basePrice - Double(i) * basePrice * 0.001
            return (p, Double.random(in: 0.1...10))
        }
        asks = (0..<20).map { i in
            let p = basePrice + Double(i) * basePrice * 0.001
            return (p, Double.random(in: 0.1...10))
        }
    }
}
