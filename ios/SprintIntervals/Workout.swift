import Foundation

/// The adjustable parts of a sprint workout. All durations are in seconds.
struct WorkoutConfig: Codable, Equatable {
    var warmup = 360
    var sprint = 30
    var rest = 90
    var sprintsPerSet = 4
    var sets = 2
    var setBreakExtra = 60
    var cooldown = 300

    var totalSprints: Int { sprintsPerSet * sets }

    /// The workout as an ordered list of intervals.
    /// The last sprint goes straight into the cooldown; the rest between sets
    /// is the normal rest plus `setBreakExtra`.
    func buildPlan() -> [Segment] {
        var plan: [Segment] = []
        if warmup > 0 { plan.append(Segment(kind: .warmup, duration: warmup)) }
        var n = 0
        for set in 1...max(sets, 1) {
            for i in 1...max(sprintsPerSet, 1) {
                n += 1
                plan.append(Segment(kind: .sprint, duration: sprint, sprintNumber: n, totalSprints: totalSprints, set: set))
                if n == totalSprints { break }
                let isSetBreak = i == sprintsPerSet
                let duration = rest + (isSetBreak ? setBreakExtra : 0)
                if duration > 0 {
                    plan.append(Segment(kind: .rest, duration: duration, sprintNumber: n, totalSprints: totalSprints, set: set, isSetBreak: isSetBreak))
                }
            }
        }
        if cooldown > 0 { plan.append(Segment(kind: .cooldown, duration: cooldown)) }
        return plan
    }

    var totalDuration: Int { buildPlan().reduce(0) { $0 + $1.duration } }

    var summary: String {
        "\(totalSprints) × \(formatLong(sprint)) / \(formatLong(rest)) rest · \(formatClock(totalDuration))"
    }
}

struct Segment: Equatable {
    enum Kind { case warmup, sprint, rest, cooldown }

    var kind: Kind
    var duration: Int
    var sprintNumber = 0
    var totalSprints = 0
    var set = 0
    var isSetBreak = false

    var title: String {
        switch kind {
        case .warmup: return "Warm-up"
        case .sprint: return "Sprint"
        case .rest: return isSetBreak ? "Set Break" : "Rest"
        case .cooldown: return "Cooldown"
        }
    }

    var listTitle: String { kind == .sprint ? "Sprint \(sprintNumber) of \(totalSprints)" : title }

    /// What the voice says when this interval starts.
    var announcement: String {
        switch kind {
        case .warmup: return "Warm up, \(spokenDuration(duration))"
        case .sprint: return sprintNumber == totalSprints ? "Last sprint. Go!" : "Sprint \(sprintNumber) of \(totalSprints). Go!"
        case .rest: return "\(isSetBreak ? "Set break" : "Rest"), \(spokenDuration(duration))"
        case .cooldown: return "Cool down, \(spokenDuration(duration))"
        }
    }
}

struct SavedWorkout: Codable, Identifiable {
    var id = UUID()
    var name: String
    var config: WorkoutConfig
}

// MARK: - Formatting

func formatClock(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return "\(s / 60):" + String(format: "%02d", s % 60)
}

func formatLong(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds) sec" }
    return seconds % 60 == 0 ? "\(seconds / 60) min" : formatClock(seconds)
}

func spokenDuration(_ seconds: Int) -> String {
    let m = seconds / 60, s = seconds % 60
    var parts: [String] = []
    if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
    if s > 0 { parts.append("\(s) second\(s == 1 ? "" : "s")") }
    return parts.joined(separator: " ")
}
