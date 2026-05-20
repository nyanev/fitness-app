import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: WorkoutManager

    var body: some View {
        if manager.activeSession != nil {
            WorkoutView()
        } else {
            NavigationStack {
                TemplateListView()
            }
        }
    }
}
