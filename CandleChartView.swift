import SwiftUI

/// 使用一个 Canvas 绘制实时 OHLC 蜡烛、网格及坐标轴。
///
/// 数据应按时间升序传入。`CandleChartModel` 已保证排序、数量上限和数值有效性。
@available(iOS 17.0, *)
struct CandleChartView: View {
    let candles: [CandleData]
    let style: CandleChartStyle

    @State private var visibleDomain: ClosedRange<Date>?
    @State private var isFollowingLatest = true
    @State private var dragStartDomain: ClosedRange<Date>?
    @State private var magnifyStartDomain: ClosedRange<Date>?

    init(
        candles: [CandleData],
        style: CandleChartStyle = .default,
        initialVisibleTimeRange: ClosedRange<Date>? = nil
    ) {
        self.candles = candles
        self.style = style
        _visibleDomain = State(initialValue: initialVisibleTimeRange)
        _isFollowingLatest = State(initialValue: initialVisibleTimeRange == nil)
    }

    var body: some View {
        GeometryReader { geometry in
            let orderedCandles = preparedCandles
            let plotRect = Self.plotRect(in: geometry.size, style: style)
            let resolvedDomain = resolvedDomain(
                candles: orderedCandles,
                plotWidth: plotRect.width
            )

            ZStack(alignment: .topTrailing) {
                Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                    draw(
                        context: &context,
                        size: size,
                        plotRect: Self.plotRect(in: size, style: style),
                        candles: orderedCandles,
                        domain: resolvedDomain
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    dragGesture(
                        plotWidth: plotRect.width,
                        candles: orderedCandles,
                        fallbackDomain: resolvedDomain
                    )
                    .simultaneously(with: magnifyGesture(
                        plotWidth: plotRect.width,
                        candles: orderedCandles,
                        fallbackDomain: resolvedDomain
                    ))
                )

                if !isFollowingLatest, !orderedCandles.isEmpty {
                    Button("回到最新") {
                        followLatest(candles: orderedCandles, fallbackDomain: resolvedDomain)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(style.currentPriceColor)
                    .foregroundStyle(style.backgroundColor)
                    .padding(.top, max(4, style.plotTopPadding))
                    .padding(.trailing, style.priceAxisWidth + 8)
                }
            }
            .onAppear {
                if visibleDomain == nil {
                    visibleDomain = resolvedDomain
                } else {
                    visibleDomain = clamped(
                        domain: resolvedDomain,
                        to: dataDomain(for: orderedCandles)
                    )
                }
            }
            .onChange(of: candles) { _ in
                synchronizeAfterDataChange(
                    candles: orderedCandles,
                    fallbackDomain: resolvedDomain
                )
            }
        }
        .background(style.backgroundColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("蜡烛图")
        .accessibilityValue(accessibilitySummary)
    }
}

@available(iOS 17.0, *)
private extension CandleChartView {
    var preparedCandles: [CandleData] {
        let valid = candles.filter(\.isValid)
        let alreadyOrdered = zip(valid, valid.dropFirst()).allSatisfy { pair in
            pair.0.time <= pair.1.time
        }
        return alreadyOrdered ? valid : valid.sorted { $0.time < $1.time }
    }

    var accessibilitySummary: String {
        guard let latest = preparedCandles.last else { return "暂无数据" }
        return "共 \(preparedCandles.count) 条，最新收盘价 \(Self.priceString(latest.close, span: 1))"
    }

    static func plotRect(in size: CGSize, style: CandleChartStyle) -> CGRect {
        CGRect(
            x: style.plotLeadingPadding,
            y: style.plotTopPadding,
            width: max(0, size.width - style.plotLeadingPadding - style.priceAxisWidth),
            height: max(0, size.height - style.plotTopPadding - style.timeAxisHeight)
        )
    }

    func resolvedDomain(candles: [CandleData], plotWidth: CGFloat) -> ClosedRange<Date> {
        if let visibleDomain {
            return normalized(domain: visibleDomain)
        }
        return defaultDomain(candles: candles, plotWidth: plotWidth)
    }

    func defaultDomain(candles: [CandleData], plotWidth: CGFloat) -> ClosedRange<Date> {
        guard let first = candles.first, let last = candles.last else {
            let now = Date()
            return now.addingTimeInterval(-60)...now
        }
        guard candles.count > 1 else {
            return first.time.addingTimeInterval(-0.5)...first.time.addingTimeInterval(0.5)
        }

        let count = min(
            candles.count,
            max(2, Int(plotWidth / max(1, style.defaultCandleSpacing)))
        )
        let start = candles[candles.count - count].time
        let interval = representativeInterval(in: Array(candles.suffix(count)))
        return start.addingTimeInterval(-interval * 0.5)
            ...last.time.addingTimeInterval(interval * 0.5)
    }

    func normalized(domain: ClosedRange<Date>) -> ClosedRange<Date> {
        let lower = domain.lowerBound
        let duration = domain.upperBound.timeIntervalSince(lower)
        if duration >= style.minimumVisibleDuration {
            return domain
        }
        return lower...lower.addingTimeInterval(style.minimumVisibleDuration)
    }

    func dataDomain(for candles: [CandleData]) -> ClosedRange<Date>? {
        guard let first = candles.first, let last = candles.last else { return nil }
        let interval = edgeInterval(in: candles)
        return first.time.addingTimeInterval(-interval * 0.5)
            ...last.time.addingTimeInterval(interval * 0.5)
    }

    func edgeInterval(in candles: [CandleData]) -> TimeInterval {
        guard candles.count > 1 else { return max(1, style.minimumVisibleDuration) }
        for index in stride(from: candles.count - 1, through: 1, by: -1) {
            let interval = candles[index].time.timeIntervalSince(candles[index - 1].time)
            if interval > 0, interval.isFinite {
                return interval
            }
        }
        return max(1, style.minimumVisibleDuration)
    }

    func representativeInterval(in candles: [CandleData]) -> TimeInterval {
        guard candles.count > 1 else { return max(1, style.minimumVisibleDuration) }
        var intervals: [TimeInterval] = []
        intervals.reserveCapacity(candles.count - 1)
        for index in 1..<candles.count {
            let interval = candles[index].time.timeIntervalSince(candles[index - 1].time)
            if interval > 0, interval.isFinite {
                intervals.append(interval)
            }
        }
        guard !intervals.isEmpty else { return max(1, style.minimumVisibleDuration) }
        intervals.sort()
        return intervals[intervals.count / 2]
    }

    func clamped(
        domain: ClosedRange<Date>,
        to dataDomain: ClosedRange<Date>?
    ) -> ClosedRange<Date> {
        guard let dataDomain else { return normalized(domain: domain) }
        let normalizedDomain = normalized(domain: domain)
        let duration = normalizedDomain.upperBound.timeIntervalSince(normalizedDomain.lowerBound)
        let dataDuration = dataDomain.upperBound.timeIntervalSince(dataDomain.lowerBound)

        if duration >= dataDuration {
            return dataDomain
        }
        if normalizedDomain.lowerBound < dataDomain.lowerBound {
            return dataDomain.lowerBound...dataDomain.lowerBound.addingTimeInterval(duration)
        }
        if normalizedDomain.upperBound > dataDomain.upperBound {
            return dataDomain.upperBound.addingTimeInterval(-duration)...dataDomain.upperBound
        }
        return normalizedDomain
    }

    func isAtLatest(_ domain: ClosedRange<Date>, candles: [CandleData]) -> Bool {
        guard let available = dataDomain(for: candles) else { return true }
        let duration = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let tolerance = max(edgeInterval(in: candles), duration * 0.01)
        return abs(domain.upperBound.timeIntervalSince(available.upperBound)) <= tolerance
    }

    func synchronizeAfterDataChange(
        candles: [CandleData],
        fallbackDomain: ClosedRange<Date>
    ) {
        guard !candles.isEmpty else {
            visibleDomain = nil
            isFollowingLatest = true
            return
        }

        let current = visibleDomain ?? fallbackDomain
        if isFollowingLatest, let available = dataDomain(for: candles) {
            let duration = current.upperBound.timeIntervalSince(current.lowerBound)
            visibleDomain = clamped(
                domain: available.upperBound.addingTimeInterval(-duration)...available.upperBound,
                to: available
            )
        } else {
            visibleDomain = clamped(domain: current, to: dataDomain(for: candles))
        }
    }

    func followLatest(candles: [CandleData], fallbackDomain: ClosedRange<Date>) {
        guard let available = dataDomain(for: candles) else { return }
        let current = visibleDomain ?? fallbackDomain
        let duration = current.upperBound.timeIntervalSince(current.lowerBound)
        visibleDomain = clamped(
            domain: available.upperBound.addingTimeInterval(-duration)...available.upperBound,
            to: available
        )
        isFollowingLatest = true
    }

    func dragGesture(
        plotWidth: CGFloat,
        candles: [CandleData],
        fallbackDomain: ClosedRange<Date>
    ) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard plotWidth > 0 else { return }
                if dragStartDomain == nil {
                    dragStartDomain = visibleDomain ?? fallbackDomain
                }
                guard let start = dragStartDomain else { return }
                let duration = start.upperBound.timeIntervalSince(start.lowerBound)
                let shift = -Double(value.translation.width / plotWidth) * duration
                let proposed = start.lowerBound.addingTimeInterval(shift)
                    ...start.upperBound.addingTimeInterval(shift)
                let result = clamped(domain: proposed, to: dataDomain(for: candles))
                visibleDomain = result
                isFollowingLatest = isAtLatest(result, candles: candles)
            }
            .onEnded { _ in
                dragStartDomain = nil
            }
    }

    func magnifyGesture(
        plotWidth: CGFloat,
        candles: [CandleData],
        fallbackDomain: ClosedRange<Date>
    ) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.005)
            .onChanged { value in
                guard plotWidth > 0 else { return }
                if magnifyStartDomain == nil {
                    magnifyStartDomain = visibleDomain ?? fallbackDomain
                }
                guard let start = magnifyStartDomain else { return }

                let startDuration = start.upperBound.timeIntervalSince(start.lowerBound)
                let scale = max(0.01, Double(value.magnification))
                let availableDuration = dataDomain(for: candles).map {
                    $0.upperBound.timeIntervalSince($0.lowerBound)
                } ?? startDuration
                let newDuration = min(
                    max(style.minimumVisibleDuration, startDuration / scale),
                    max(style.minimumVisibleDuration, availableDuration)
                )
                let anchorRatio = min(1, max(0, Double(value.startAnchor.x)))
                let anchorTime = start.lowerBound.addingTimeInterval(startDuration * anchorRatio)
                let proposed = anchorTime.addingTimeInterval(-newDuration * anchorRatio)
                    ...anchorTime.addingTimeInterval(newDuration * (1 - anchorRatio))
                let result = clamped(domain: proposed, to: dataDomain(for: candles))
                visibleDomain = result
                isFollowingLatest = isAtLatest(result, candles: candles)
            }
            .onEnded { _ in
                magnifyStartDomain = nil
            }
    }
}

@available(iOS 17.0, *)
private extension CandleChartView {
    func draw(
        context: inout GraphicsContext,
        size: CGSize,
        plotRect: CGRect,
        candles: [CandleData],
        domain: ClosedRange<Date>
    ) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(style.backgroundColor))
        guard plotRect.width > 1, plotRect.height > 1 else { return }
        context.fill(Path(plotRect), with: .color(style.plotBackgroundColor))

        let visible = visibleCandles(in: candles, domain: domain, includingNeighbors: true)
        let strictlyVisible = visibleCandles(in: candles, domain: domain, includingNeighbors: false)
        let priceDomain = priceDomain(for: strictlyVisible.isEmpty ? visible : strictlyVisible)
        drawGridAndAxes(
            context: &context,
            size: size,
            plotRect: plotRect,
            timeDomain: domain,
            priceDomain: priceDomain
        )

        var plotContext = context
        plotContext.clip(to: Path(plotRect))
        drawCandles(
            context: &plotContext,
            plotRect: plotRect,
            candles: visible,
            timeDomain: domain,
            priceDomain: priceDomain
        )

        if let latest = candles.last {
            drawCurrentPrice(
                context: &context,
                plotRect: plotRect,
                price: latest.close,
                priceDomain: priceDomain
            )
        }

        var border = Path()
        border.move(to: CGPoint(x: plotRect.maxX, y: plotRect.minY))
        border.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.maxY))
        border.addLine(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        context.stroke(border, with: .color(style.gridColor), lineWidth: style.gridLineWidth)
    }

    func visibleCandles(
        in candles: [CandleData],
        domain: ClosedRange<Date>,
        includingNeighbors: Bool
    ) -> ArraySlice<CandleData> {
        guard !candles.isEmpty else { return candles[...] }
        let first = lowerBound(in: candles, date: domain.lowerBound)
        let afterLast = upperBound(in: candles, date: domain.upperBound)
        let padding = includingNeighbors ? 1 : 0
        let lower = max(0, first - padding)
        let upper = min(candles.count, afterLast + padding)
        return candles[lower..<upper]
    }

    func lowerBound(in candles: [CandleData], date: Date) -> Int {
        var lower = 0
        var upper = candles.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if candles[middle].time < date {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    func upperBound(in candles: [CandleData], date: Date) -> Int {
        var lower = 0
        var upper = candles.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if candles[middle].time <= date {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    func priceDomain(for candles: ArraySlice<CandleData>) -> ClosedRange<Double> {
        guard let first = candles.first else { return 0...1 }
        var low = first.normalizedLow
        var high = first.normalizedHigh
        for candle in candles.dropFirst() {
            low = min(low, candle.normalizedLow)
            high = max(high, candle.normalizedHigh)
        }

        let rawSpan = high - low
        let base = max(abs(high), abs(low), 1)
        let effectiveSpan = rawSpan > 0 ? rawSpan : base * 0.01
        let padding = effectiveSpan * max(0, style.verticalPricePaddingRatio)
        return (low - padding)...(high + padding)
    }

    func xPosition(for date: Date, domain: ClosedRange<Date>, rect: CGRect) -> CGFloat {
        let duration = domain.upperBound.timeIntervalSince(domain.lowerBound)
        guard duration > 0 else { return rect.midX }
        let ratio = date.timeIntervalSince(domain.lowerBound) / duration
        return rect.minX + CGFloat(ratio) * rect.width
    }

    func yPosition(for price: Double, domain: ClosedRange<Double>, rect: CGRect) -> CGFloat {
        let span = domain.upperBound - domain.lowerBound
        guard span > 0 else { return rect.midY }
        let ratio = (price - domain.lowerBound) / span
        return rect.maxY - CGFloat(ratio) * rect.height
    }

    func drawGridAndAxes(
        context: inout GraphicsContext,
        size: CGSize,
        plotRect: CGRect,
        timeDomain: ClosedRange<Date>,
        priceDomain: ClosedRange<Double>
    ) {
        let priceTicks = max(2, min(style.priceTickCount, Int(plotRect.height / 44) + 1))
        let timeTicks = max(2, min(style.timeTickCount, Int(plotRect.width / 92) + 1))

        for index in 0..<priceTicks {
            let ratio = Double(index) / Double(priceTicks - 1)
            let price = priceDomain.upperBound - ratio * (priceDomain.upperBound - priceDomain.lowerBound)
            let y = plotRect.minY + CGFloat(ratio) * plotRect.height
            var line = Path()
            line.move(to: CGPoint(x: plotRect.minX, y: y))
            line.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            context.stroke(line, with: .color(style.gridColor), lineWidth: style.gridLineWidth)

            context.draw(
                Text(Self.priceString(price, span: priceDomain.upperBound - priceDomain.lowerBound))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(style.axisTextColor),
                at: CGPoint(x: min(size.width - 2, plotRect.maxX + 5), y: y),
                anchor: .leading
            )
        }

        let duration = timeDomain.upperBound.timeIntervalSince(timeDomain.lowerBound)
        for index in 0..<timeTicks {
            let ratio = Double(index) / Double(timeTicks - 1)
            let date = timeDomain.lowerBound.addingTimeInterval(duration * ratio)
            let x = plotRect.minX + CGFloat(ratio) * plotRect.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: plotRect.minY))
            line.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(line, with: .color(style.gridColor), lineWidth: style.gridLineWidth)

            let anchor: UnitPoint = index == 0 ? .topLeading : (index == timeTicks - 1 ? .topTrailing : .top)
            context.draw(
                Text(Self.timeString(date, duration: duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(style.axisTextColor),
                at: CGPoint(x: x, y: plotRect.maxY + 5),
                anchor: anchor
            )
        }
    }

    func drawCandles(
        context: inout GraphicsContext,
        plotRect: CGRect,
        candles: ArraySlice<CandleData>,
        timeDomain: ClosedRange<Date>,
        priceDomain: ClosedRange<Double>
    ) {
        guard !candles.isEmpty else { return }
        let interval = representativeInterval(in: Array(candles))
        let duration = max(style.minimumVisibleDuration, timeDomain.upperBound.timeIntervalSince(timeDomain.lowerBound))
        let rawWidth = plotRect.width * CGFloat(interval / duration) * style.candleWidthRatio
        let bodyWidth = min(style.maximumCandleSpacing, max(style.minimumCandleSpacing, rawWidth))

        var risingWicks = Path()
        var fallingWicks = Path()
        var neutralWicks = Path()
        var risingBodies = Path()
        var fallingBodies = Path()
        var neutralBodies = Path()

        for candle in candles {
            let x = xPosition(for: candle.time, domain: timeDomain, rect: plotRect)
            let highY = yPosition(for: candle.normalizedHigh, domain: priceDomain, rect: plotRect)
            let lowY = yPosition(for: candle.normalizedLow, domain: priceDomain, rect: plotRect)
            let openY = yPosition(for: candle.open, domain: priceDomain, rect: plotRect)
            let closeY = yPosition(for: candle.close, domain: priceDomain, rect: plotRect)
            let bodyTop = min(openY, closeY)
            let bodyHeight = max(style.minimumBodyHeight, abs(closeY - openY))
            let bodyRect = CGRect(
                x: x - bodyWidth / 2,
                y: bodyTop,
                width: bodyWidth,
                height: bodyHeight
            )

            if candle.close > candle.open {
                risingWicks.move(to: CGPoint(x: x, y: highY))
                risingWicks.addLine(to: CGPoint(x: x, y: lowY))
                risingBodies.addRect(bodyRect)
            } else if candle.close < candle.open {
                fallingWicks.move(to: CGPoint(x: x, y: highY))
                fallingWicks.addLine(to: CGPoint(x: x, y: lowY))
                fallingBodies.addRect(bodyRect)
            } else {
                neutralWicks.move(to: CGPoint(x: x, y: highY))
                neutralWicks.addLine(to: CGPoint(x: x, y: lowY))
                neutralBodies.addRect(bodyRect)
            }
        }

        context.stroke(risingWicks, with: .color(style.risingColor), lineWidth: style.wickLineWidth)
        context.stroke(fallingWicks, with: .color(style.fallingColor), lineWidth: style.wickLineWidth)
        context.stroke(neutralWicks, with: .color(style.neutralColor), lineWidth: style.wickLineWidth)
        context.fill(risingBodies, with: .color(style.risingColor))
        context.fill(fallingBodies, with: .color(style.fallingColor))
        context.fill(neutralBodies, with: .color(style.neutralColor))
    }

    func drawCurrentPrice(
        context: inout GraphicsContext,
        plotRect: CGRect,
        price: Double,
        priceDomain: ClosedRange<Double>
    ) {
        guard price >= priceDomain.lowerBound, price <= priceDomain.upperBound else { return }
        let y = yPosition(for: price, domain: priceDomain, rect: plotRect)
        var line = Path()
        line.move(to: CGPoint(x: plotRect.minX, y: y))
        line.addLine(to: CGPoint(x: plotRect.maxX, y: y))
        context.stroke(
            line,
            with: .color(style.currentPriceColor),
            style: StrokeStyle(lineWidth: style.currentPriceLineWidth, dash: [4, 3])
        )

        let label = Text(Self.priceString(price, span: priceDomain.upperBound - priceDomain.lowerBound))
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(style.currentPriceColor)
        let labelRect = CGRect(
            x: plotRect.maxX + 1,
            y: y - 9,
            width: max(0, style.priceAxisWidth - 2),
            height: 18
        )
        context.fill(Path(labelRect), with: .color(style.backgroundColor))
        context.draw(label, at: CGPoint(x: plotRect.maxX + 5, y: y), anchor: .leading)
    }

    static func priceString(_ value: Double, span: Double) -> String {
        let decimals: Int
        switch abs(span) {
        case 100...: decimals = 0
        case 1...: decimals = 2
        case 0.01...: decimals = 4
        default: decimals = 6
        }
        return value.formatted(.number.precision(.fractionLength(decimals)))
    }

    static func timeString(_ date: Date, duration: TimeInterval) -> String {
        if duration >= 86_400 {
            return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)))
        }
        return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    }
}
