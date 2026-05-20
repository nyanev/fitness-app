import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var manager: WorkoutManager

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if manager.isResting {
                RestTimerView()
            } else if let session = manager.activeSession {
                ExerciseSetView(session: session)
            }

            if manager.heartRate > 0 {
                Label("\(Int(manager.heartRate))", systemImage: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 2)
                    .padding(.trailing, 2)
            }
        }
    }
}
