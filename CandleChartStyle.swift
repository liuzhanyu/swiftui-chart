import SwiftUI

struct CandleChartStyle {
    var backgroundColor = Color(red: 0.055, green: 0.071, blue: 0.105)
    var plotBackgroundColor = Color(red: 0.075, green: 0.094, blue: 0.135)
    var gridColor = Color.white.opacity(0.10)
    var axisTextColor = Color.white.opacity(0.62)
    var risingColor = Color(red: 0.15, green: 0.80, blue: 0.55)
    var fallingColor = Color(red: 1.00, green: 0.36, blue: 0.42)
    var neutralColor = Color.white.opacity(0.72)
    var currentPriceColor = Color(red: 0.96, green: 0.78, blue: 0.25)

    var priceAxisWidth: CGFloat = 68
    var timeAxisHeight: CGFloat = 28
    var plotTopPadding: CGFloat = 10
    var plotLeadingPadding: CGFloat = 8

    var minimumCandleSpacing: CGFloat = 2
    var maximumCandleSpacing: CGFloat = 42
    var defaultCandleSpacing: CGFloat = 9
    var candleWidthRatio: CGFloat = 0.68
    var minimumBodyHeight: CGFloat = 1

    var priceTickCount: Int = 5
    var timeTickCount: Int = 5

    var gridLineWidth: CGFloat = 0.5
    var wickLineWidth: CGFloat = 1
    var currentPriceLineWidth: CGFloat = 1
    var verticalPricePaddingRatio: Double = 0.05
    var minimumVisibleDuration: TimeInterval = 1

    static let `default` = CandleChartStyle()
}
