import Foundation

struct WatchTemplate: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let exercises: [WatchExercise]
}

struct WatchExercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let targetSets: Int
    let targetReps: Int
    let targetWeight: Double?
    let restSeconds: Int
    let orderIndex: Int

    var displayTarget: String {
        if let w = targetWeight, w > 0 {
            let wStr = w.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(w))
                : String(format: "%.1f", w)
            return "\(targetSets)×\(targetReps) @ \(wStr)kg"
        }
        return "\(targetSets)×\(targetReps)"
    }
}

struct ActiveWatchSession {
    let id: String
    let template: WatchTemplate
    var currentExerciseIndex: Int
    var setsCompleted: [Int]
    var actualReps: [Int]
    var actualWeight: [Double]       // 0 = bodyweight
    var actualRestSeconds: [Int]

    init(template: WatchTemplate) {
        self.id = UUID().uuidString
        self.template = template
        self.currentExerciseIndex = 0
        self.setsCompleted = Array(repeating: 0, count: template.exercises.count)
        self.actualReps = template.exercises.map { $0.targetReps }
        self.actualWeight = template.exercises.map { $0.targetWeight ?? 0 }
        self.actualRestSeconds = template.exercises.map { max($0.restSeconds, 15) }
    }

    var currentExercise: WatchExercise { template.exercises[currentExerciseIndex] }
    var currentReps: Int { actualReps[currentExerciseIndex] }
    var currentWeight: Double { actualWeight[currentExerciseIndex] }
    var currentRestSeconds: Int { actualRestSeconds[currentExerciseIndex] }
    var setsCompletedForCurrent: Int { setsCompleted[currentExerciseIndex] }
    var isCurrentExerciseDone: Bool { setsCompletedForCurrent >= currentExercise.targetSets }
    var isFirstExercise: Bool { currentExerciseIndex == 0 }
    var isLastExercise: Bool { currentExerciseIndex >= template.exercises.count - 1 }
}
