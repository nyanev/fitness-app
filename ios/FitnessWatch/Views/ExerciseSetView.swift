import SwiftUI

struct ExerciseSetView: View {
    let session: ActiveWatchSession
    @EnvironmentObject var manager: WorkoutManager
    @State private var showFinish = false

    private var exercise: WatchExercise { session.currentExercise }
    private var completed: Int { session.setsCompletedForCurrent }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                // Exercise navigator
                HStack {
                    Button {
                        manager.previousExercise()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(session.isFirstExercise)

                    Spacer()

                    Text("\(session.currentExerciseIndex + 1) / \(session.template.exercises.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        manager.nextExercise()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(session.isLastExercise)
                }

                // Name + target
                Text(exercise.name)
                    .font(.headline)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(exercise.displayTarget)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Set progress dots
                HStack(spacing: 5) {
                    ForEach(0..<exercise.targetSets, id: \.self) { i in
                        Circle()
                            .fill(i < completed ? Color.green : Color.secondary.opacity(0.3))
                            .frame(width: 9, height: 9)
                    }
                }
                .padding(.vertical, 2)

                // Complete Set
                Button {
                    manager.completeSet()
                } label: {
                    Label("Complete Set", systemImage: "checkmark")
                        .font(.footnote.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(session.isCurrentExerciseDone)

                // Elapsed
                Text(elapsedString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()

                // Finish
                Button(role: .destructive) {
                    showFinish = true
                } label: {
                    Text("Finish")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 4)
            .padding(.top, 28)   // leave room for HR chip
        }
        .confirmationDialog("Finish Workout?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Finish", role: .destructive) { manager.finishWorkout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var elapsedString: String {
        let m = manager.elapsedSeconds / 60
        let s = manager.elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
