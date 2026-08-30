// ============================================================
// KLineChartView.swift
// QuantDashboard - K 线图表视图（Canvas 自绘 + 手势）
// ============================================================

import SwiftUI

// MARK: - K 线图表视图
struct KLineChartView: View {

    @ObservedObject var marketVM: MarketViewModel
    @ObservedObject var indicatorVM: IndicatorViewModel

    @State private var crosshairPosition: CGPoint? = nil
    @State private var selectedCandle: CandleData? = nil
    @State private var showCrosshair: Bool = false

    @State private var zoomLevel: CGFloat = 1.0
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var lastZoomScale: CGFloat = 1.0

    @State private var showLandscape = false

    private let minVisibleCandles = 20
    private let maxVisibleCandles = 200

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                intervalSelector
                priceInfoBar
                kLineMainChart
                volumeChart
                indicatorSubCharts
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .fullScreenCover(isPresented: $showLandscape) {
            LandscapeKLineView(marketVM: marketVM, indicatorVM: indicatorVM)
        }
    }

    // MARK: - 可见 K 线数量
    private var visibleCount: Int {
        let base: CGFloat = 60
        let count = Int(base / zoomLevel)
        return min(max(count, minVisibleCandles), maxVisibleCandles)
    }

    // MARK: - 可见 K 线数组
    private func getVisibleCandles(from candles: [CandleData]) -> [CandleData] {
        guard !candles.isEmpty else { return [] }
        let total = candles.count
        let count = min(visibleCount, total)

        let maxOffset = max(0, total - count)
        let offset = Int(-scrollOffset / 10)
        let safeOffset = min(max(offset, 0), maxOffset)

        let start = total - count - safeOffset
        return Array(candles[max(start, 0)..<min(start + count, total)])
    }

    // MARK: - 周期选择器
    private var intervalSelector: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(KLineInterval.allCases) { interval in
                        GlassButton(
                            title: interval.displayName,
                            icon: nil,
                            isSelected: marketVM.currentInterval == interval
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                marketVM.switchInterval(to: interval)
                                scrollOffset = 0
                            }
                        }
                    }
                }
            }
            Spacer()
            LandscapeButton { showLandscape = true }
        }
    }

    // MARK: - 价格信息栏
    private var priceInfoBar: some View {
        HStack(spacing: 16) {
            if let candle = selectedCandle {
                infoItem(label: "开", value: String(format: "%.2f", candle.open))
                infoItem(label: "高", value: String(format: "%.2f", candle.high))
                infoItem(label: "低", value: String(format: "%.2f", candle.low))
                infoItem(label: "收", value: String(format: "%.2f", candle.close))
                infoItem(label: "量", value: formatVolume(candle.volume))
            } else {
                infoItem(label: "最新价", value: marketVM.formattedPrice)
                infoItem(label: "涨跌", value: marketVM.formattedChange)
                infoItem(label: "最高", value: String(format: "%.2f", marketVM.high24h))
                infoItem(label: "最低", value: String(format: "%.2f", marketVM.low24h))
                infoItem(label: "成交量", value: marketVM.formattedVolume)
            }
        }
        .padding(.vertical, 10)
        .liquidGlass(cornerRadius: 12, fillOpacity: 0.03)
    }

    private func infoItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - K 线主图
    private var kLineMainChart: some View {
        let candles = marketVM.candles
        let visibleCandles = getVisibleCandles(from: candles)

        return GlassCard(title: "K线图", icon: "chart.xyaxis.line") {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let size = geo.size
                    let priceMin = visibleCandles.map(\.low).min() ?? 0
                    let priceMax = visibleCandles.map(\.high).max() ?? 1
                    let priceRange = priceMax - priceMin
                    let candleWidth = size.width / CGFloat(visibleCandles.count)
                    let bodyWidth = max(candleWidth * 0.7, 2)

                    ZStack {
                        gridLines(in: size, priceMin: priceMin, priceMax: priceMax)

                    Canvas { context, canvasSize in
                        for (i, candle) in visibleCandles.enumerated() {
                            let x = CGFloat(i) * candleWidth + candleWidth / 2

                            func y(_ price: Double) -> CGFloat {
                                guard price.isFinite else { return size.height / 2 }
                                let ratio = priceRange > 0
                                    ? (price - priceMin) / priceRange : 0.5
                                return size.height * (1 - CGFloat(ratio))
                            }

                                let bodyTop = y(max(candle.open, candle.close))
                                let bodyBottom = y(min(candle.open, candle.close))
                                let bodyHeight = max(bodyBottom - bodyTop, 1)

                                let color: Color = candle.isBullish
                                    ? LiquidGlassTheme.bullishAccent
                                    : LiquidGlassTheme.bearishAccent

                                var shadowPath = Path()
                                shadowPath.move(to: CGPoint(x: x, y: y(candle.high)))
                                shadowPath.addLine(to: CGPoint(x: x, y: y(candle.low)))
                                context.stroke(shadowPath, with: .color(color.opacity(0.6)), lineWidth: 1)

                                let bodyRect = CGRect(
                                    x: x - bodyWidth / 2,
                                    y: bodyTop,
                                    width: bodyWidth,
                                    height: bodyHeight
                                )
                                let bodyPath = Path(roundedRect: bodyRect, cornerRadius: 1)
                                context.fill(bodyPath, with: .color(color))
                            }
                        }
                        .frame(width: size.width, height: size.height)

                        if showCrosshair, let pos = crosshairPosition {
                            crosshairView(at: pos, size: size,
                                         visibleCandles: visibleCandles,
                                         candleWidth: candleWidth,
                                         priceMin: priceMin, priceMax: priceMax)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if showCrosshair {
                                    crosshairPosition = value.location
                                    let index = Int(value.location.x / candleWidth)
                                    if index >= 0 && index < visibleCandles.count {
                                        selectedCandle = visibleCandles[index]
                                    }
                                } else {
                                    let delta = value.translation.width - lastScrollOffset
                                    scrollOffset += delta
                                    lastScrollOffset = value.translation.width
                                }
                            }
                            .onEnded { _ in
                                if showCrosshair {
                                    showCrosshair = false
                                    selectedCandle = nil
                                }
                                lastScrollOffset = 0
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                let delta = scale / lastZoomScale
                                zoomLevel = min(max(zoomLevel * delta, 0.3), 5.0)
                                lastZoomScale = scale
                            }
                            .onEnded { _ in
                                lastZoomScale = 1.0
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showCrosshair.toggle()
                                    if !showCrosshair {
                                        selectedCandle = nil
                                    }
                                }
                            }
                    )
                }
                .frame(height: 300)
            }
        }
    }

    // MARK: - 网格线
    private func gridLines(in size: CGSize, priceMin: Double, priceMax: Double) -> some View {
        Canvas { context, canvasSize in
            let gridCount = 5
            for i in 0...gridCount {
                let y = size.height * CGFloat(i) / CGFloat(gridCount)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
            }
        }
    }

    // MARK: - 十字光标
    private func crosshairView(at pos: CGPoint, size: CGSize,
                                visibleCandles: [CandleData], candleWidth: CGFloat,
                                priceMin: Double, priceMax: Double) -> some View {
            _ = min(max(Int(pos.x / candleWidth), 0), max(visibleCandles.count - 1, 0))
        let priceRange = priceMax - priceMin
        let priceAtCursor = priceRange > 0
            ? priceMax - Double(pos.y / size.height) * priceRange : 0

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: pos.y))
                path.addLine(to: CGPoint(x: size.width, y: pos.y))
            }
            .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

            Path { path in
                path.move(to: CGPoint(x: pos.x, y: 0))
                path.addLine(to: CGPoint(x: pos.x, y: size.height))
            }
            .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

            Text(String(format: "%.2f", priceAtCursor))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.8)))
                .position(x: size.width - 35, y: pos.y)

            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .position(pos)
        }
    }

    // MARK: - 成交量图
    private var volumeChart: some View {
        let candles = marketVM.candles
        let visibleCandles = getVisibleCandles(from: candles)

        return GlassCard(title: "成交量", icon: "chart.bar.fill") {
            GeometryReader { geo in
                let size = geo.size
                let maxVol = visibleCandles.map(\.volume).max() ?? 1
                let candleWidth = size.width / CGFloat(visibleCandles.count)
                let barWidth = max(candleWidth * 0.7, 2)

                Canvas { context, canvasSize in
                    for (i, candle) in visibleCandles.enumerated() {
                        let x = CGFloat(i) * candleWidth + candleWidth / 2
                        let barHeight = maxVol > 0
                            ? CGFloat(candle.volume / maxVol) * size.height : 0
                        let barRect = CGRect(
                            x: x - barWidth / 2,
                            y: size.height - barHeight,
                            width: barWidth,
                            height: barHeight
                        )
                        let color: Color = candle.isBullish
                            ? LiquidGlassTheme.bullishAccent.opacity(0.5)
                            : LiquidGlassTheme.bearishAccent.opacity(0.5)
                        context.fill(Path(barRect), with: .color(color))
                    }
                }
            }
            .frame(height: 80)
        }
    }

    // MARK: - 副图指标区
    private var indicatorSubCharts: some View {
        VStack(spacing: 12) {
            ForEach(1...5, id: \.self) { index in
                if indicatorVM.result(for: index) != nil {
                    IndicatorSubChart(
                        index: index,
                        name: indicatorVM.result(for: index)?.indicatorName ?? "指标\(index)",
                        timeSeries: indicatorVM.timeSeries(for: index)
                    )
                }
            }
        }
    }

    private func formatVolume(_ vol: Double) -> String {
        if vol >= 1_000_000 { return String(format: "%.1fM", vol / 1_000_000) }
        if vol >= 1_000 { return String(format: "%.1fK", vol / 1_000) }
        return String(format: "%.0f", vol)
    }
}

// MARK: - 指标副图
struct IndicatorSubChart: View {

    let index: Int
    let name: String
    let timeSeries: [IndicatorTimePoint]

    var body: some View {
        GlassCard(title: "M\(index) \(name)", icon: "waveform") {
            GeometryReader { geo in
                let size = geo.size
                let values = timeSeries.map(\.mainValue)
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 1
                let range = maxVal - minVal

                    Canvas { context, canvasSize in
                        guard values.count > 1 else { return }
                        let stepX = size.width / CGFloat(values.count - 1)

                        var path = Path()
                        for (i, val) in values.enumerated() {
                            guard val.isFinite else { continue }
                            let x = CGFloat(i) * stepX
                            let y = range > 0
                                ? size.height * (1 - CGFloat((val - minVal) / range))
                                : size.height / 2
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    context.stroke(
                        path,
                        with: .color(LiquidGlassTheme.neutralAccent),
                        lineWidth: 1.5
                    )
                }
            }
            .frame(height: 80)
        }
    }
}
