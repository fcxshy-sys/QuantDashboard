// ============================================================
// GoldDataProvider.swift
// QuantDashboard - 黄金行情数据提供器
// 使用新浪财经 + 东方财富 免费接口
// ============================================================

import Foundation
import Combine

class GoldDataProvider: ObservableObject {

    @Published var currentPrice: Double = 0
    @Published var priceChange24h: Double = 0
    @Published var priceChangePercent24h: Double = 0
    @Published var isConnected: Bool = false
    @Published var historicalCandles: [CandleData] = []

    var onPriceUpdate: ((Double, Double, Double) -> Void)?
    var onCandlesUpdate: (([CandleData]) -> Void)?

    private var pollingTimer: Timer?
    private var dataRefreshTimer: Timer?

    // MARK: - 新浪财经 API (实时金价)
    // 新浪财经代码: hf_GC (COMEX黄金期货), hf_XAU (现货黄金)
    private let sinaURL = "https://hq.sinajs.cn/list=hf_GC"

    // MARK: - 东方财富 API (历史K线)
    // 现货黄金 secid: 120.XAUUSD
    private let eastmoneyBase = "https://push2his.eastmoney.com/api/qt/stock/kline/get"

    init() {}

    func startPolling(interval: TimeInterval = 3) {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchCurrentPrice()
        }
        fetchCurrentPrice()

        dataRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchHistoricalData()
        }
        fetchHistoricalData()
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        dataRefreshTimer?.invalidate()
    }

    // MARK: - 新浪财经实时金价
    func fetchCurrentPrice() {
        guard let url = URL(string: sinaURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data,
                  let text = String(data: data, encoding: .utf8)
            else { return }

            // 格式: var hq_str_hf_GC="黄金2408,2398.5,2400.1,...";
            guard let start = text.firstIndex(of: "\""),
                  let end = text.lastIndex(of: "\""),
                  start != end else { return }

            let values = String(text[text.index(after: start)..<end])
                .components(separatedBy: ",")

            // 字段: 0名称 1开盘 2昨收 3最高 4最低 5现价 6买价 7卖价 ... 等
            guard values.count > 5,
                  let price = Double(values[5]),
                  let open = Double(values[2]),
                  price > 0 else { return }

            let change = price - open
            let changePercent = open != 0 ? (change / open * 100) : 0

            DispatchQueue.main.async {
                self?.currentPrice = price
                self?.priceChange24h = change
                self?.priceChangePercent24h = changePercent
                self?.isConnected = true
                self?.onPriceUpdate?(price, change, changePercent)
            }
        }.resume()
    }

    // MARK: - 东方财富历史K线
    func fetchHistoricalData(period: String = "101") {
        // period: 101=日K, 102=周K, 103=月K, 60=1分钟, 30=5分钟, 15=15分钟, 5=30分钟, 1=60分钟
        guard var components = URLComponents(string: eastmoneyBase) else { return }
        components.queryItems = [
            URLQueryItem(name: "secid", value: "120.XAUUSD"),
            URLQueryItem(name: "fields1", value: "f1,f2,f3,f4,f5,f6"),
            URLQueryItem(name: "fields2", value: "f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61"),
            URLQueryItem(name: "klt", value: period),
            URLQueryItem(name: "fqt", value: "1"),
            URLQueryItem(name: "end", value: "20500101"),
            URLQueryItem(name: "lmt", value: "200"),
            URLQueryItem(name: "ut", value: "fa5fd1943c7b386f172d6893dbbd4568")
        ]

        guard let url = components.url else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let klines = dataDict["klines"] as? [String]
            else { return }

            var candles: [CandleData] = []
            for line in klines {
                // 格式: "日期,开,收,高,低,成交量,成交额,振幅,涨跌幅,涨跌额,换手率"
                let parts = line.components(separatedBy: ",")
                guard parts.count >= 6,
                      let open = Double(parts[1]),
                      let close = Double(parts[2]),
                      let high = Double(parts[3]),
                      let low = Double(parts[4]),
                      let volume = Double(parts[5])
                else { continue }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let date = formatter.date(from: parts[0]) ?? Date()

                let candle = CandleData(
                    openTime: date, open: open, high: high, low: low,
                    close: close, volume: volume,
                    closeTime: date.addingTimeInterval(86399)
                )
                candles.append(candle)
            }

            DispatchQueue.main.async {
                self?.historicalCandles = candles
                self?.onCandlesUpdate?(candles)
            }
        }.resume()
    }

    func generateMockCandles(count: Int = 200, basePrice: Double = 2400.0) -> [CandleData] {
        var candles: [CandleData] = []
        var price = basePrice
        let now = Date()
        for i in 0..<count {
            let time = now.addingTimeInterval(Double(-(count - i)) * 3600)
            let change = Double.random(in: -0.002...0.002)
            let open = price
            let close = price * (1 + change)
            let high = max(open, close) * (1 + Double.random(in: 0...0.001))
            let low = min(open, close) * (1 - Double.random(in: 0...0.001))
            candles.append(CandleData(
                openTime: time, open: open, high: high, low: low,
                close: close, volume: Double.random(in: 1000...50000),
                closeTime: time.addingTimeInterval(3599)
            ))
            price = close
        }
        return candles
    }
}
