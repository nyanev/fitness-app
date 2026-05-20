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
    var setsCompleted: [Int]       // count per exercise

    init(template: WatchTemplate) {
        self.id = UUID().uuidString
        self.template = template
        self.currentExerciseIndex = 0
        self.setsCompleted = Array(repeating: 0, count: template.exercises.count)
    }

    var currentExercise: WatchExercise {
        template.exercises[currentExerciseIndex]
    }

    var setsCompletedForCurrent: Int {
        setsCompleted[currentExerciseIndex]
    }

    var isCurrentExerciseDone: Bool {
        setsCompletedForCurrent >= currentExercise.targetSets
    }

    var isFirstExercise: Bool { currentExerciseIndex == 0 }
    var isLastExercise: Bool { currentExerciseIndex >= template.exercises.count - 1 }
}
