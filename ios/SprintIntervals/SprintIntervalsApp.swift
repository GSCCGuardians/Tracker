import SwiftUI

@main
struct SprintIntervalsApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var engine = WorkoutEngine()

    var body: some Scene {
        WindowGroup {
            SetupView()
                .environmentObject(settings)
                .environmentObject(engine)
                .preferredColorScheme(.dark)
        }
    }
}

extension Segment.Kind {
    var color: Color {
        switch self {
        case .warmup: return .orange
        case .sprint: return .red
        case .rest: return .green
        case .cooldown: return .blue
        }
    }
}
