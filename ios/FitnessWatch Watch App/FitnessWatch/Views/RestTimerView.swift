import SwiftUI

struct RestTimerView: View {
    @EnvironmentObject var manager: WorkoutManager

    private var progress: Double {
        guard manager.restTotalSeconds > 0 else { return 1 }
        return Double(manager.restSecondsRemaining) / Double(manager.restTotalSeconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 0) {
                    Text(timeString)
                        .font(.title3.monospacedDigit().bold())
                    Text("Rest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            HStack(spacing: 10) {
                Button("-15s") {
                    manager.adjustActiveRest(delta: -15)
                }
                .buttonStyle(.bordered)
                .font(.caption2)

                Button("Skip") {
                    manager.skipRest()
                }
                .buttonStyle(.bordered)
                .font(.footnote)

                Button("+15s") {
                    manager.adjustActiveRest(delta: 15)
                }
                .buttonStyle(.bordered)
                .font(.caption2)
            }
        }
    }

    private var timeString: String {
        let m = manager.restSecondsRemaining / 60
        let s = manager.restSecondsRemaining % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }
}
