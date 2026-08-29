// ============================================================
// CandleData.swift
// QuantDashboard - K线蜡烛数据模型
// ============================================================

import Foundation

// MARK: - K线蜡烛数据（标准 OHLCV）
struct CandleData: Identifiable, Codable {
    let id: UUID
    let openTime: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let closeTime: Date

    /// 涨跌幅百分比
    var changePercent: Double {
        guard open != 0 else { return 0 }
        return (close - open) / open * 100
    }

    /// 是否收阳
    var isBullish: Bool { close >= open }

    /// 实体高度
    var bodyHeight: Double { abs(close - open) }

    /// 上影线长度
    var upperShadow: Double { high - max(open, close) }

    /// 下影线长度
    var lowerShadow: Double { min(open, close) - low }

    init(openTime: Date, open: Double, high: Double, low: Double,
         close: Double, volume: Double, closeTime: Date) {
        self.id = UUID()
        self.openTime = openTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.closeTime = closeTime
    }

    // MARK: - 从 Binance K线 JSON 解码
    /// Binance kline 数组格式: [openTime, open, high, low, close, volume, closeTime, ...]
    init?(binanceJSON: [Any]) {
        guard binanceJSON.count >= 7,
              let openTimeMs = binanceJSON[0] as? TimeInterval,
              let open = Double("\(binanceJSON[1])"),
              let high = Double("\(binanceJSON[2])"),
              let low = Double("\(binanceJSON[3])"),
              let close = Double("\(binanceJSON[4])"),
              let volume = Double("\(binanceJSON[5])"),
              let closeTimeMs = binanceJSON[6] as? TimeInterval
        else { return nil }

        self.id = UUID()
        self.openTime = Date(timeIntervalSince1970: openTimeMs / 1000)
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.closeTime = Date(timeIntervalSince1970: closeTimeMs / 1000)
    }
}

// MARK: - WebSocket 实时逐笔推送数据
struct RealtimeTrade: Identifiable {
    let id = UUID()
    let symbol: String
    let price: Double
    let quantity: Double
    let time: Date
    let isBuyerMaker: Bool

    /// 成交金额
    var turnover: Double { price * quantity }
}

// MARK: - 24小时行情摘要
struct Ticker24h {
    let symbol: String
    let lastPrice: Double
    let priceChange: Double
    let priceChangePercent: Double
    let high24h: Double
    let low24h: Double
    let volume24h: Double
    let quoteVolume24h: Double
    let timestamp: Date
}
