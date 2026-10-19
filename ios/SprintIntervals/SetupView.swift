import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: WorkoutEngine
    @State private var showingSave = false
    @State private var saveName = ""

    var body: some View {
        let plan = settings.config.buildPlan()
        let total = plan.reduce(0) { $0 + $1.duration }

        NavigationStack {
            List {
                Section {
                    HStack {
                        stat(formatClock(total), "Total time")
                        Divider()
                        stat("\(settings.config.totalSprints)", "Sprints")
                    }
                    TimelineBar(plan: plan, total: total)
                }

                Section("Intervals") {
                    ValueStepper(title: "Warm-up", subtitle: "Before the first sprint", color: .orange,
                                 value: $settings.config.warmup, step: 30, range: 0...3600, isTime: true)
                    ValueStepper(title: "Sprint", subtitle: "Each work interval", color: .red,
                                 value: $settings.config.sprint, step: 5, range: 5...600, isTime: true)
                    ValueStepper(title: "Rest", subtitle: "Between sprints", color: .green,
                                 value: $settings.config.rest, step: 5, range: 0...600, isTime: true)
                    ValueStepper(title: "Sprints per set", subtitle: "Sprints in each group",
                                 value: $settings.config.sprintsPerSet, step: 1, range: 1...30)
                    ValueStepper(title: "Sets", subtitle: "Number of groups",
                                 value: $settings.config.sets, step: 1, range: 1...10)
                    ValueStepper(title: "Extra set rest", subtitle: "Added to the rest between sets", color: .green,
                                 value: $settings.config.setBreakExtra, step: 15, range: 0...600, isTime: true)
                    ValueStepper(title: "Cooldown", subtitle: "After the last sprint", color: .blue,
                                 value: $settings.config.cooldown, step: 30, range: 0...3600, isTime: true)
                }

                Section {
                    Toggle("Beeps", isOn: $settings.beeps)
                    Toggle("Voice", isOn: $settings.voice)
                    Toggle("Keep screen on", isOn: $settings.keepScreenOn)
                } header: {
                    Text("Sounds")
                } footer: {
                    Text("Cues play over Apple Music without stopping it, even with the phone locked or on silent.")
                }

                Section("Saved workouts") {
                    ForEach(settings.saved) { workout in
                        Button {
                            settings.config = workout.config
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name).foregroundStyle(.primary)
                                Text(workout.config.summary).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { settings.saved.remove(atOffsets: $0) }
                    Button("Save current settings…") {
                        saveName = "\(settings.config.totalSprints) × \(formatLong(settings.config.sprint)) sprints"
                        showingSave = true
                    }
                }

                Section("Plan") {
                    ForEach(Array(startTimes(plan).enumerated()), id: \.offset) { _, row in
                        HStack {
                            Circle().fill(row.segment.kind.color).frame(width: 10, height: 10)
                            Text(row.segment.listTitle)
                            Spacer()
                            Text(formatLong(row.segment.duration)).monospacedDigit()
                            Text(formatClock(row.start))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Sprint Intervals")
            .safeAreaInset(edge: .bottom) {
                Button {
                    engine.start(settings: settings)
                } label: {
                    Text("Start Workout")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .alert("Save workout", isPresented: $showingSave) {
                TextField("Name", text: $saveName)
                Button("Save") {
                    let name = saveName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { settings.saved.append(SavedWorkout(name: name, config: settings.config)) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $engine.isPresented) {
                RunView().environmentObject(engine)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startTimes(_ plan: [Segment]) -> [(segment: Segment, start: Int)] {
        var t = 0
        return plan.map { seg in
            defer { t += seg.duration }
            return (seg, t)
        }
    }
}

/// A row with a label and +/- buttons. Press and hold to change quickly.
struct ValueStepper: View {
    let title: String
    let subtitle: String
    var color: Color? = nil
    @Binding var value: Int
    let step: Int
    let range: ClosedRange<Int>
    var isTime = false

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack(spacing: 10) {
                Circle().fill(color ?? .clear).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Text(isTime ? formatClock(value) : "\(value)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        }
    }
}

/// The whole workout as coloured blocks, sized by duration.
struct TimelineBar: View {
    let plan: [Segment]
    let total: Int

    var body: some View {
        GeometryReader { geo in
            let gaps = CGFloat(max(plan.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(Array(plan.enumerated()), id: \.offset) { _, seg in
                    seg.kind.color
                        .frame(width: max(1, (geo.size.width - gaps) * CGFloat(seg.duration) / CGFloat(max(total, 1))))
                }
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
    }
}
