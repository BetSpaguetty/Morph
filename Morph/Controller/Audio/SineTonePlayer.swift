import AVFoundation

@MainActor
final class SineTonePlayer {
    private let frequency: Double = 130
    private let amplitude: Float = 0.08 // 0.025
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var isPlaying = false

    func start() {
        guard !isPlaying else { return }

        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            #endif

            let audioEngine = AVAudioEngine()
            let audioPlayer = AVAudioPlayerNode()
            let sampleRate = audioEngine.outputNode.inputFormat(forBus: 0).sampleRate
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let frameCount = AVAudioFrameCount(sampleRate)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
            buffer.frameLength = frameCount

            if let samples = buffer.floatChannelData?[0] {
                for frame in 0..<Int(frameCount) {
                    let phase = 2.0 * Double.pi * frequency * Double(frame) / sampleRate
                    samples[frame] = amplitude * Float(sin(phase))
                }
            }

            audioEngine.attach(audioPlayer)
            audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: format)
            audioPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
            try audioEngine.start()
            audioPlayer.play()

            engine = audioEngine
            player = audioPlayer
            isPlaying = true
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        isPlaying = false

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
