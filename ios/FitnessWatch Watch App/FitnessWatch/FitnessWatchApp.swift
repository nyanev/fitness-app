import SwiftUI

@main
struct FitnessWatchApp: App {
    @StateObject private var manager = WorkoutManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
        }
    }
}
