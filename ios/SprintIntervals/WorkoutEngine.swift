import Combine
import UIKit

/// Runs a workout: tracks the current interval and fires the cues.
/// Times are measured against the clock, so the countdown stays accurate.
@MainActor
final class WorkoutEngine: ObservableObject {
    @Published private(set) var plan: [Segment] = []
    @Published private(set) var index = 0
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var isPaused = false
    @Published private(set) var isFinished = false
    @Published var isPresented = false

    private var segmentEnd = Date()
    private var timer: Timer?
    private var lastBeepSecond: Int?
    private var beeps = true
    private var voice = true
    private let audio = AudioCues()

    var current: Segment? { plan.indices.contains(index) ? plan[index] : nil }
    var next: Segment? { plan.indices.contains(index + 1) ? plan[index + 1] : nil }
    var totalDuration: TimeInterval { TimeInterval(plan.reduce(0) { $0 + $1.duration }) }
    var totalSprints: Int { plan.filter { $0.kind == .sprint }.count }
    var sprintsStarted: Int { plan.isEmpty ? 0 : plan[...min(index, plan.count - 1)].filter { $0.kind == .sprint }.count }

    var elapsed: TimeInterval {
        if isFinished { return totalDuration }
        guard let seg = current else { return 0 }
        let before = plan[..<index].reduce(0) { $0 + $1.duration }
        return TimeInterval(before + seg.duration) - remaining
    }

    func start(settings: AppSettings) {
        plan = settings.config.buildPlan()
        guard !plan.isEmpty else { return }
        beeps = settings.beeps
        voice = settings.voice
        isPaused = false
        isFinished = false
        audio.activate()
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenOn
        isPresented = true
        enter(0)

        timer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func togglePause() {
        guard !isFinished else { return }
        if isPaused {
            segmentEnd = Date().addingTimeInterval(remaining)
            isPaused = false
        } else {
            tick()
            isPaused = true
        }
    }

    /// First tap restarts the current interval; tap again within 2 seconds to go back one.
    func back() {
        guard !isFinished, let seg = current else { return }
        let intoSegment = TimeInterval(seg.duration) - remaining
        enter(intoSegment > 2 ? index : max(index - 1, 0))
    }

    func skip() {
        guard !isFinished else { return }
        if index >= plan.count - 1 { finish() } else { enter(index + 1) }
    }

    func close() {
        timer?.invalidate()
        timer = nil
        audio.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false
        isPresented = false
    }

    private func enter(_ i: Int) {
        index = i
        remaining = TimeInterval(plan[i].duration)
        segmentEnd = Date().addingTimeInterval(remaining)
        lastBeepSecond = nil
        cue(plan[i])
    }

    private func tick() {
        guard !isPaused, !isFinished, !plan.isEmpty else { return }
        let now = Date()
        var advanced = false
        while now >= segmentEnd {
            if index >= plan.count - 1 { finish(); return }
            index += 1
            segmentEnd = segmentEnd.addingTimeInterval(TimeInterval(plan[index].duration))
            lastBeepSecond = nil
            advanced = true
        }
        if advanced { cue(plan[index]) }
        remaining = segmentEnd.timeIntervalSince(now)

        let second = Int(ceil(remaining))
        if beeps, (1...3).contains(second), second != lastBeepSecond, plan[index].duration > 3 {
            lastBeepSecond = second
            audio.play(second == 1 ? .finalTick : .tick)
        }
    }

    private func cue(_ seg: Segment) {
        if beeps {
            switch seg.kind {
            case .sprint: audio.play(.go)
            case .rest: audio.play(.rest)
            case .warmup, .cooldown: audio.play(.change)
            }
        }
        if voice { audio.say(seg.announcement) }
    }

    private func finish() {
        isFinished = true
        isPaused = false
        remaining = 0
        timer?.invalidate()
        timer = nil
        if beeps { audio.play(.finish) }
        if voice { audio.say("Workout complete. Nice work!") }
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
