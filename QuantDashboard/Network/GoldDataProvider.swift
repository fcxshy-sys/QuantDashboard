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
    var onError: ((String) -> Void)?

    private var pollingTimer: Timer?
    private var dataRefreshTimer: Timer?
    private var currentPriceTask: URLSessionDataTask?
    private var currentKLineTask: URLSessionDataTask?

    private let sinaURL = "https://hq.sinajs.cn/list=hf_GC"
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
        pollingTimer = nil
        dataRefreshTimer = nil
        currentPriceTask?.cancel()
        currentKLineTask?.cancel()
    }

    func fetchCurrentPrice() {
        currentPriceTask?.cancel()
        guard let url = URL(string: sinaURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 5

        currentPriceTask = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            guard let data = data,
                  let text = String(data: data, encoding: .utf8) else {
                if let error = error {
                    DispatchQueue.main.async {
                        self.onError?("金价请求失败: \(error.localizedDescription)")
                    }
                }
                return
            }

            guard let start = text.firstIndex(of: "\""),
                  let end = text.lastIndex(of: "\""),
                  start != end else { return }

            let values = String(text[text.index(after: start)..<end])
                .components(separatedBy: ",")

            guard values.count > 5,
                  let price = Double(values[5]),
                  let open = Double(values[2]),
                  price > 0 else { return }

            let change = price - open
            let changePercent = open != 0 ? (change / open * 100) : 0

            DispatchQueue.main.async {
                self.currentPrice = price
                self.priceChange24h = change
                self.priceChangePercent24h = changePercent
                self.isConnected = true
                self.onPriceUpdate?(price, change, changePercent)
            }
        }
        currentPriceTask?.resume()
    }

    func fetchHistoricalData(period: String = "101") {
        currentKLineTask?.cancel()

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

        currentKLineTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let klines = dataDict["klines"] as? [String]
            else {
                if let error = error {
                    DispatchQueue.main.async {
                        self.onError?("K线数据加载失败: \(error.localizedDescription)")
                    }
                }
                return
            }

            var candles: [CandleData] = []
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            for line in klines {
                let parts = line.components(separatedBy: ",")
                guard parts.count >= 6,
                      let open = Double(parts[1]),
                      let close = Double(parts[2]),
                      let high = Double(parts[3]),
                      let low = Double(parts[4]),
                      let volume = Double(parts[5])
                else { continue }

                let date = formatter.date(from: parts[0]) ?? Date()

                let candle = CandleData(
                    openTime: date, open: open, high: high, low: low,
                    close: close, volume: volume,
                    closeTime: date.addingTimeInterval(86399)
                )
                candles.append(candle)
            }

            DispatchQueue.main.async {
                self.historicalCandles = candles
                self.onCandlesUpdate?(candles)
            }
        }
        currentKLineTask?.resume()
    }
}
