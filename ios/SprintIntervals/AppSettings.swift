import Combine
import Foundation

/// Workout settings and saved workouts, kept in UserDefaults.
final class AppSettings: ObservableObject {
    @Published var config: WorkoutConfig { didSet { save() } }
    @Published var saved: [SavedWorkout] { didSet { save() } }
    @Published var beeps: Bool { didSet { save() } }
    @Published var voice: Bool { didSet { save() } }
    @Published var keepScreenOn: Bool { didSet { save() } }

    private struct Stored: Codable {
        var config: WorkoutConfig
        var saved: [SavedWorkout]
        var beeps: Bool
        var voice: Bool
        var keepScreenOn: Bool
    }

    private static let key = "sprintIntervals.settings"

    init() {
        let stored = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
            ?? Stored(config: WorkoutConfig(),
                      saved: [SavedWorkout(name: "8 × 30s sprints (default)", config: WorkoutConfig())],
                      beeps: true, voice: true, keepScreenOn: true)
        config = stored.config
        saved = stored.saved
        beeps = stored.beeps
        voice = stored.voice
        keepScreenOn = stored.keepScreenOn
    }

    private func save() {
        let stored = Stored(config: config, saved: saved, beeps: beeps, voice: voice, keepScreenOn: keepScreenOn)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
