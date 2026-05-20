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

                // Exercise name
                Text(exercise.name)
                    .font(.headline)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Reps adjuster
                adjRow(
                    label: "\(session.currentReps) reps",
                    onMinus: { manager.adjustReps(delta: -1) },
                    onPlus: { manager.adjustReps(delta: 1) }
                )

                // Weight adjuster
                adjRow(
                    label: session.currentWeight > 0 ? weightLabel(session.currentWeight) : "BW",
                    onMinus: { manager.adjustWeight(delta: -0.5) },
                    onPlus: { manager.adjustWeight(delta: 0.5) }
                )

                // Rest adjuster
                adjRow(
                    label: "\(session.currentRestSeconds)s rest",
                    onMinus: { manager.adjustRestDefault(delta: -5) },
                    onPlus: { manager.adjustRestDefault(delta: 5) }
                )

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
            .padding(.top, 28)
        }
        .confirmationDialog("Finish Workout?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Finish", role: .destructive) { manager.finishWorkout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func adjRow(label: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Button(action: onMinus) {
                Image(systemName: "minus")
                    .font(.caption2.bold())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer()

            Text(label)
                .font(.caption)
                .monospacedDigit()
                .minimumScaleFactor(0.8)

            Spacer()

            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.caption2.bold())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    private func weightLabel(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(w))kg"
            : String(format: "%.1fkg", w)
    }

    private var elapsedString: String {
        let m = manager.elapsedSeconds / 60
        let s = manager.elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
