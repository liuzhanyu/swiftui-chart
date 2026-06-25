import Foundation
import SwiftUI

@MainActor
final class CandleChartModel: ObservableObject {
    @Published private(set) var candles: [CandleData]

    let maximumCount: Int
    private var demoUpdateTask: Task<Void, Never>?

    init(candles: [CandleData] = [], maximumCount: Int = 2_000) {
        self.maximumCount = max(1, maximumCount)
        self.candles = Self.prepared(candles, maximumCount: self.maximumCount)
    }

    /// 接入真实行情时调用。数组始终保留最新的 `maximumCount` 条。
    @discardableResult
    func append(_ candle: CandleData) -> Bool {
        guard candle.isValid else { return false }

        if let last = candles.last, last.time <= candle.time {
            candles.append(candle)
        } else {
            let insertionIndex = candles.partitioningIndex { $0.time > candle.time }
            candles.insert(candle, at: insertionIndex)
        }

        if candles.count > maximumCount {
            candles.removeFirst(candles.count - maximumCount)
        }

        return true
    }

    /// 更新当前周期的最后一根蜡烛。空模型会将它作为第一根插入。
    /// 若时间发生变化，数据仍会重新放入正确的时间位置。
    @discardableResult
    func updateLast(_ candle: CandleData) -> Bool {
        guard candle.isValid else { return false }

        var updated = candles
        if !updated.isEmpty {
            updated.removeLast()
        }
        let insertionIndex = updated.partitioningIndex { $0.time > candle.time }
        updated.insert(candle, at: insertionIndex)
        candles = Array(updated.suffix(maximumCount))
        return true
    }

    func replaceAll(with newCandles: [CandleData]) {
        candles = Self.prepared(newCandles, maximumCount: maximumCount)
    }

    /// 生成 2000 条初始数据，仅用于 Demo。
    func loadDemoDataIfNeeded() {
        guard candles.isEmpty else { return }

        var result: [CandleData] = []
        result.reserveCapacity(maximumCount)

        var price = 100.0
        let startTime = Date().addingTimeInterval(-Double(maximumCount - 1))

        for index in 0..<maximumCount {
            let candle = Self.makeDemoCandle(
                previousClose: price,
                time: startTime.addingTimeInterval(Double(index))
            )
            result.append(candle)
            price = candle.close
        }

        candles = result
    }

    /// 每秒更新最后一条 Demo 数据；真实项目中直接调用 `updateLast(_:)`。
    /// 新周期开始时由调用方使用 `append(_:)` 加入下一根蜡烛。
    func startDemoUpdates() {
        guard demoUpdateTask == nil else { return }

        demoUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }

                guard let self else { break }
                if let latest = self.candles.last {
                    self.updateLast(Self.makeDemoUpdate(for: latest))
                } else {
                    self.append(Self.makeDemoCandle(previousClose: 100, time: Date()))
                }
            }
        }
    }

    func stopDemoUpdates() {
        demoUpdateTask?.cancel()
        demoUpdateTask = nil
    }

    private static func makeDemoCandle(previousClose: Double, time: Date) -> CandleData {
        let open = previousClose
        let close = max(0.01, open + Double.random(in: -1.25...1.25))
        let high = max(open, close) + Double.random(in: 0.08...0.75)
        let low = max(0.01, min(open, close) - Double.random(in: 0.08...0.75))

        return CandleData(
            time: time,
            open: open,
            close: close,
            high: high,
            low: low
        )
    }

    private static func makeDemoUpdate(for candle: CandleData) -> CandleData {
        let close = max(0.01, candle.close + Double.random(in: -0.7...0.7))
        return CandleData(
            id: candle.id,
            time: candle.time,
            open: candle.open,
            close: close,
            high: max(candle.normalizedHigh, close),
            low: min(candle.normalizedLow, close)
        )
    }

    private static func prepared(
        _ candles: [CandleData],
        maximumCount: Int
    ) -> [CandleData] {
        Array(
            candles
                .filter(\.isValid)
                .sorted { $0.time < $1.time }
                .suffix(maximumCount)
        )
    }
}


private extension Array {
    /// 返回第一个满足谓词的位置；数组需已按相同条件排序。
    func partitioningIndex(where belongsInSecondPartition: (Element) -> Bool) -> Int {
        var lower = startIndex
        var upper = endIndex

        while lower < upper {
            let middle = lower + distance(from: lower, to: upper) / 2
            if belongsInSecondPartition(self[middle]) {
                upper = middle
            } else {
                lower = middle + 1
            }
        }

        return lower
    }
}
