import SwiftUI

struct RunView: View {
    @EnvironmentObject private var engine: WorkoutEngine
    @State private var confirmEnd = false

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: engine.index)

            VStack(spacing: 12) {
                HStack {
                    Button("End") {
                        if engine.isFinished { engine.close() } else { confirmEnd = true }
                    }
                    .font(.headline)
                    Spacer()
                    Text("Sprints \(engine.sprintsStarted)/\(engine.totalSprints)").monospacedDigit()
                    Spacer()
                    Color.clear.frame(width: 40, height: 1)
                }

                Spacer(minLength: 8)

                Text(phaseTitle)
                    .font(.system(size: 44, weight: .heavy))
                    .textCase(.uppercase)
                Text(subtitle)
                    .font(.title3)
                    .opacity(0.85)

                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(formatClock(Int(ceil(engine.remaining - 0.001))))
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                }
                .padding(24)
                .frame(maxWidth: 360)

                Text(nextText)
                    .font(.headline)
                    .opacity(0.9)

                ProgressView(value: min(engine.elapsed, engine.totalDuration), total: max(engine.totalDuration, 1))
                    .tint(.white)
                HStack {
                    Text(formatClock(Int(engine.elapsed)))
                    Spacer()
                    Text("-" + formatClock(Int(engine.totalDuration - engine.elapsed)))
                }
                .font(.subheadline)
                .monospacedDigit()
                .opacity(0.85)

                Spacer(minLength: 8)

                HStack(spacing: 36) {
                    roundButton("backward.end.fill", size: 64, label: "Previous interval") { engine.back() }
                    Button {
                        engine.togglePause()
                    } label: {
                        Image(systemName: engine.isPaused || engine.isFinished ? "play.fill" : "pause.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.black)
                            .frame(width: 88, height: 88)
                            .background(Circle().fill(.white))
                    }
                    .accessibilityLabel(engine.isPaused ? "Resume" : "Pause")
                    roundButton("forward.end.fill", size: 64, label: "Next interval") { engine.skip() }
                }
                .disabled(engine.isFinished)
                .opacity(engine.isFinished ? 0.4 : 1)
            }
            .padding()
            .foregroundStyle(.white)
        }
        .confirmationDialog("End this workout?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Workout", role: .destructive) { engine.close() }
        }
    }

    private var background: Color {
        if engine.isFinished { return .purple }
        return engine.current?.kind.color ?? .black
    }

    private var phaseTitle: String {
        if engine.isFinished { return "Done" }
        if engine.isPaused { return "Paused" }
        return engine.current?.title ?? ""
    }

    private var subtitle: String {
        if engine.isFinished {
            return "\(engine.totalSprints) sprints · \(formatClock(Int(engine.totalDuration)))"
        }
        guard let seg = engine.current else { return "" }
        switch seg.kind {
        case .sprint: return "\(seg.sprintNumber) of \(seg.totalSprints)"
        case .rest: return "\(seg.sprintNumber) of \(seg.totalSprints) done" + (seg.isSetBreak ? " · set \(seg.set + 1) next" : "")
        case .warmup, .cooldown: return ""
        }
    }

    private var nextText: String {
        if engine.isFinished { return "Nice work!" }
        guard let next = engine.next else { return "Last interval" }
        let name = next.kind == .sprint ? "Sprint \(next.sprintNumber)" : next.title
        return "Next: \(name) · \(formatLong(next.duration))"
    }

    private var progress: CGFloat {
        if engine.isFinished { return 1 }
        guard let seg = engine.current, seg.duration > 0 else { return 0 }
        return CGFloat(1 - engine.remaining / TimeInterval(seg.duration))
    }

    private func roundButton(_ symbol: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .frame(width: size, height: size)
                .background(Circle().fill(.black.opacity(0.22)))
        }
        .accessibilityLabel(label)
    }
}
