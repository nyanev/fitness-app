import SwiftUI

struct TemplateListView: View {
    @EnvironmentObject var manager: WorkoutManager

    var body: some View {
        Group {
            if manager.templates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Open the iPhone app to sync workouts")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(manager.templates) { template in
                    Button {
                        manager.startWorkout(template: template)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.headline)
                            Text("\(template.exercises.count) exercises")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Workouts")
    }
}
