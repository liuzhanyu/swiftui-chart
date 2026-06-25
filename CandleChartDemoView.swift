import SwiftUI

/// 可直接放进 NavigationStack 或 App 入口的运行示例。
@available(iOS 17.0, *)
struct CandleChartDemoView: View {
    @StateObject private var model = CandleChartModel()

    var body: some View {
        VStack(spacing: 12) {
            header

            CandleChartView(candles: model.candles)
                .frame(maxWidth: .infinity)
                .frame(height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("开启下一周期") {
                appendNextPeriod()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(red: 0.035, green: 0.045, blue: 0.068).ignoresSafeArea())
        .foregroundStyle(.white)
        .onAppear {
            model.loadDemoDataIfNeeded()
            model.startDemoUpdates()
        }
        .onDisappear {
            model.stopDemoUpdates()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("实时蜡烛图")
                    .font(.headline)
                Text("双指缩放 · 拖动查看历史")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let latest = model.candles.last {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(latest.close.formatted(.number.precision(.fractionLength(2))))
                        .font(.title3.monospacedDigit().weight(.semibold))
                    Text("\(model.candles.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func appendNextPeriod() {
        let previousClose = model.candles.last?.close ?? 100
        let previousTime = model.candles.last?.time ?? Date()
        let nextTime = max(Date(), previousTime.addingTimeInterval(1))
        let close = max(0.01, previousClose + Double.random(in: -1...1))

        model.append(
            CandleData(
                time: nextTime,
                open: previousClose,
                close: close,
                high: max(previousClose, close) + Double.random(in: 0.05...0.5),
                low: max(0.01, min(previousClose, close) - Double.random(in: 0.05...0.5))
            )
        )
    }
}


#Preview {
    CandleChartDemoView()
}
