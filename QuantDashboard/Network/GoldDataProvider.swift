// ============================================================
// GoldDataProvider.swift
// QuantDashboard - 黄金行情数据提供器
// 支持多种免费/低延迟数据源
// ============================================================

import Foundation
import Combine

// MARK: - 黄金数据提供器
/// 接入主流免费金融行情接口获取 XAU/USD 实时与历史数据
class GoldDataProvider: ObservableObject {

    // MARK: - Published 状态
    @Published var currentPrice: Double = 0
    @Published var priceChange24h: Double = 0
    @Published var priceChangePercent24h: Double = 0
    @Published var isConnected: Bool = false
    @Published var historicalCandles: [CandleData] = []

    // MARK: - 数据源配置
    /// 可配置的数据源类型
    enum DataSourceType: String, CaseIterable {
        case finnhub = "Finnhub"
        case alphaVantage = "Alpha Vantage"
        case metalsAPI = "Metals API"
        case websocketAgg = "WebSocket聚合"
    }

    // MARK: - 私有属性
    private var pollingTimer: Timer?
    private var dataRefreshTimer: Timer?
    private let dataQueue = DispatchQueue(label: "gold.data.queue", qos: .userInitiated)

    // MARK: - Finnhub 配置（免费额度: 60次/分钟）
    private let finnhubAPIKey = "YOUR_FINNHUB_API_KEY"  // 替换为实际 Key
    private let finnhubBaseURL = "https://finnhub.io/api/v1"

    // MARK: - Alpha Vantage 配置（免费额度: 5次/分钟）
    private let alphaVantageKey = "YOUR_ALPHA_VANTAGE_KEY"
    private let alphaVantageBaseURL = "https://www.alphavantage.co/query"

    // MARK: - 初始化
    init() {}

    // MARK: - 启动数据拉取
    func startPolling(interval: TimeInterval = 5) {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchCurrentPrice()
        }
        fetchCurrentPrice()

        // 每分钟刷新历史数据
        dataRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchHistoricalData()
        }
        fetchHistoricalData()
    }

    /// 停止数据拉取
    func stopPolling() {
        pollingTimer?.invalidate()
        dataRefreshTimer?.invalidate()
    }

    // MARK: - 获取当前金价（Finnhub）
    func fetchCurrentPrice() {
        let urlString = "\(finnhubBaseURL)/quote?symbol=OANDA:XAU_USD&token=\(finnhubAPIKey)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["c"] as? Double,
                  let previousClose = json["pc"] as? Double
            else { return }

            DispatchQueue.main.async {
                self?.currentPrice = current
                self?.priceChange24h = current - previousClose
                self?.priceChangePercent24h = previousClose != 0
                    ? (current - previousClose) / previousClose * 100 : 0
                self?.isConnected = true
            }
        }.resume()
    }

    // MARK: - 获取历史 K 线（Alpha Vantage）
    func fetchHistoricalData(function: String = "FX_DAILY", from: String? = nil, to: String? = nil) {
        let fromDate = from ?? formatDate(Date().addingTimeInterval(-30 * 86400))
        let toDate = to ?? formatDate(Date())

        var urlString = "\(alphaVantageBaseURL)?function=\(function)&from_symbol=XAU&to_symbol=USD"
        urlString += "&apikey=\(alphaVantageKey)&outputsize=compact"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timeSeries = json["Time Series FX (Daily)"] as? [String: [String: String]]
            else { return }

            var candles: [CandleData] = []
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]

            for (dateStr, values) in timeSeries {
                guard let open = Double(values["1. open"] ?? ""),
                      let high = Double(values["2. high"] ?? ""),
                      let low = Double(values["3. low"] ?? ""),
                      let close = Double(values["4. close"] ?? "")
                else { continue }

                let date = dateFormatter.date(from: dateStr + "T00:00:00Z") ?? Date()
                let candle = CandleData(
                    openTime: date, open: open, high: high, low: low,
                    close: close, volume: 0,
                    closeTime: date.addingTimeInterval(86399)
                )
                candles.append(candle)
            }

            candles.sort { $0.openTime < $1.openTime }

            DispatchQueue.main.async {
                self?.historicalCandles = candles
            }
        }.resume()
    }

    // MARK: - 生成模拟 K 线数据（数据源不可用时的降级方案）
    func generateMockCandles(count: Int = 200, basePrice: Double = 2400.0) -> [CandleData] {
        var candles: [CandleData] = []
        var price = basePrice
        let now = Date()

        for i in 0..<count {
            let time = now.addingTimeInterval(Double(-(count - i)) * 3600)
            let volatility = 0.002  // 0.2% 波动率
            let change = Double.random(in: -volatility...volatility)
            let open = price
            let close = price * (1 + change)
            let high = max(open, close) * (1 + Double.random(in: 0...volatility * 0.5))
            let low = min(open, close) * (1 - Double.random(in: 0...volatility * 0.5))
            let volume = Double.random(in: 1000...50000)

            let candle = CandleData(
                openTime: time, open: open, high: high, low: low,
                close: close, volume: volume,
                closeTime: time.addingTimeInterval(3599)
            )
            candles.append(candle)
            price = close
        }
        return candles
    }

    // MARK: - 工具方法
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
