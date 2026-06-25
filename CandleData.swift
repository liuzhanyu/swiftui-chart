import Foundation

/// 一根 OHLC 蜡烛数据。数据应按 `time` 升序传给图表。
struct CandleData: Identifiable, Equatable, Sendable {
    let id: UUID
    let time: Date
    let open: Double
    let close: Double
    let high: Double
    let low: Double

    init(
        id: UUID = UUID(),
        time: Date,
        open: Double,
        close: Double,
        high: Double,
        low: Double
    ) {
        self.id = id
        self.time = time
        self.open = open
        self.close = close
        self.high = high
        self.low = low
    }

    /// 将不规范行情中的 OHLC 一并纳入范围，避免实体超出影线。
    var normalizedHigh: Double {
        max(high, low, open, close)
    }

    var normalizedLow: Double {
        min(high, low, open, close)
    }

    /// 非有限数值无法安全映射到 Canvas 坐标，因此在进入模型前拒绝。
    var isValid: Bool {
        time.timeIntervalSinceReferenceDate.isFinite
            && open.isFinite
            && close.isFinite
            && high.isFinite
            && low.isFinite
    }
}
