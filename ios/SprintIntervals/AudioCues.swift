import AVFoundation

/// Beeps and voice cues that play over Apple Music without pausing it.
///
/// While a workout runs, a silent loop keeps the audio engine going. Together
/// with the "audio" background mode this keeps the timer and its cues running
/// with the screen locked or another app open. The `.playback` category also
/// means the ring/silent switch does not mute the cues.
final class AudioCues {
    enum Tone { case go, rest, change, tick, finalTick, finish }

    private let engine = AVAudioEngine()
    private let silenceNode = AVAudioPlayerNode()
    private let toneNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let speech = AVSpeechSynthesizer()
    private var isActive = false
    private var observers: [NSObjectProtocol] = []

    private lazy var silentBuffer: AVAudioPCMBuffer = {
        let frames = AVAudioFrameCount(format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) { data[i] = 0 }
        return buffer
    }()

    init() {
        engine.attach(silenceNode)
        engine.attach(toneNode)
        engine.connect(silenceNode, to: engine.mainMixerNode, format: format)
        engine.connect(toneNode, to: engine.mainMixerNode, format: format)

        let center = NotificationCenter.default
        // Restart after a phone call or Siri interruption ends.
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, self.isActive,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            self.startEngine()
        })
        // Restart when the output changes, e.g. AirPods connected or removed.
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.startEngine()
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        isActive = true
        startEngine()
    }

    func deactivate() {
        isActive = false
        speech.stopSpeaking(at: .immediate)
        silenceNode.stop()
        toneNode.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startEngine() {
        do {
            if !engine.isRunning { try engine.start() }
            silenceNode.stop()
            silenceNode.scheduleBuffer(silentBuffer, at: nil, options: .loops)
            silenceNode.play()
            toneNode.play()
        } catch {
            print("Audio engine error: \(error)")
        }
    }

    func play(_ tone: Tone) {
        // (frequency, seconds); a frequency of 0 is a gap.
        let notes: [(Double, Double)]
        switch tone {
        case .go: notes = [(1320, 0.18), (0, 0.05), (1320, 0.35)]
        case .rest: notes = [(660, 0.45)]
        case .change: notes = [(880, 0.4)]
        case .tick: notes = [(880, 0.12)]
        case .finalTick: notes = [(990, 0.12)]
        case .finish: notes = [(880, 0.2), (0, 0.03), (1100, 0.2), (0, 0.03), (1320, 0.5)]
        }
        guard isActive, let buffer = makeBuffer(notes) else { return }
        if !engine.isRunning { startEngine() }
        toneNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !toneNode.isPlaying { toneNode.play() }
    }

    func say(_ text: String) {
        guard isActive else { return }
        if speech.isSpeaking { speech.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.volume = 1
        speech.speak(utterance)
    }

    private func makeBuffer(_ notes: [(Double, Double)]) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let total = notes.reduce(0) { $0 + Int($1.1 * rate) }
        guard total > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(total)
        let data = buffer.floatChannelData![0]
        let attack = 0.01 * rate, release = 0.04 * rate
        var offset = 0
        for (freq, seconds) in notes {
            let count = Int(seconds * rate)
            for i in 0..<count {
                var sample: Float = 0
                if freq > 0 {
                    let envelope = min(1, Double(i) / attack) * min(1, Double(count - i) / release)
                    sample = Float(sin(2 * .pi * freq * Double(i) / rate) * 0.6 * envelope)
                }
                data[offset + i] = sample
            }
            offset += count
        }
        return buffer
    }
}
