import AVFoundation

/// A short synthesized brass fanfare with a timpani hit, played through a hall reverb.
@MainActor
final class Fanfare {
    nonisolated static let sampleRate = 44_100.0

    private var samples: [Float]?
    private var engine: AVAudioEngine?

    init() {
        Task.detached(priority: .utility) {
            let rendered = Self.render()
            await MainActor.run { [weak self] in self?.samples = rendered }
        }
    }

    func play() {
        stop()
        let samples = self.samples ?? Self.render()
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 2)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channels = buffer.floatChannelData
        else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for i in samples.indices {
            channels[0][i] = samples[i]
            channels[1][i] = samples[i]
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 30
        engine.attach(player)
        engine.attach(reverb)
        engine.connect(player, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            Log.app.error("Fanfare audio engine failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        player.scheduleBuffer(buffer, at: nil)
        player.play()
        self.engine = engine

        let seconds = Double(samples.count) / Self.sampleRate + 3  // let the reverb tail ring out
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            if self?.engine === engine { self?.stop() }
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }

    // MARK: - Synthesis

    private struct Note: Sendable {
        let start: Double
        let duration: Double
        let frequencies: [Double]
    }

    nonisolated private static let G4 = 392.00, C5 = 523.25, E5 = 659.25, G5 = 783.99, D5 = 587.33
    nonisolated private static let B4 = 493.88, E4 = 329.63, C4 = 261.63

    nonisolated private static let score: [Note] = [
        Note(start: 0.00, duration: 0.12, frequencies: [G4]),
        Note(start: 0.15, duration: 0.12, frequencies: [G4]),
        Note(start: 0.30, duration: 0.12, frequencies: [G4]),
        Note(start: 0.45, duration: 0.70, frequencies: [C5, G4, E4]),
        Note(start: 1.20, duration: 0.20, frequencies: [E5, C5, G4]),
        Note(start: 1.43, duration: 0.20, frequencies: [D5, B4, G4]),
        Note(start: 1.66, duration: 2.10, frequencies: [G5, E5, C5, G4, C4]),
    ]

    nonisolated private static let timpaniHits: [Double] = [0.45, 1.66]

    nonisolated private static func render() -> [Float] {
        let length = 4.2
        let count = Int(length * sampleRate)
        var out = [Float](repeating: 0, count: count)

        for note in score {
            let first = Int(note.start * sampleRate)
            let last = min(count, Int((note.start + note.duration + 0.15) * sampleRate))
            for i in first..<last {
                let t = Double(i) / sampleRate - note.start
                let env = brassEnvelope(t, duration: note.duration)
                guard env > 0 else { continue }
                // Brass: bright upper harmonics bloom during the attack; gentle vibrato on long notes.
                let vibrato = note.duration > 0.5 ? 0.35 * sin(2 * .pi * 5.5 * t) * min(1, max(0, t - 0.3) / 0.4) : 0
                let bloom = 1 + 1.8 * exp(-t * 14)
                var sample = 0.0
                for (index, frequency) in note.frequencies.enumerated() {
                    let voiceGain = index == 0 ? 1.0 : 0.6
                    for harmonic in 1...9 {
                        let h = Double(harmonic)
                        let amplitude = pow(0.68, h - 1) * (harmonic > 2 ? bloom : 1)
                        for detune in [0.9985, 1.0015] {
                            sample += voiceGain * amplitude * sin(2 * .pi * frequency * detune * h * t + h * vibrato)
                        }
                    }
                }
                out[i] += Float(env * sample)
            }
        }

        for hit in timpaniHits {
            let first = Int(hit * sampleRate)
            for i in first..<min(count, first + Int(2.0 * sampleRate)) {
                let t = Double(i - first) / sampleRate
                let pitch = 65.4 * (1 + 0.15 * exp(-t * 20))
                let body = sin(2 * .pi * pitch * t) * exp(-t * 3.2)
                let thump = sin(2 * .pi * 120 * t) * exp(-t * 25) * 0.5
                out[i] += Float((body + thump) * 6)
            }
        }

        let peak = out.map(abs).max() ?? 1
        let gain = peak > 0 ? 0.7 / peak : 1
        return out.map { $0 * gain }
    }

    nonisolated private static func brassEnvelope(_ t: Double, duration: Double) -> Double {
        let attack = 0.035
        let release = 0.15
        if t < 0 { return 0 }
        if t < attack { return t / attack }
        if t < duration {
            let decay = 1 - 0.25 * min(1, (t - attack) / 0.15)
            return decay
        }
        let r = (t - duration) / release
        return r < 1 ? 0.75 * (1 - r) : 0
    }
}
