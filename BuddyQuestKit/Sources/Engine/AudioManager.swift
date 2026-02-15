import Foundation
import AVFoundation

/// Manages background music and sound effects
public final class AudioManager {
    public static let shared = AudioManager()

    private var musicPlayer: AVAudioPlayer?
    private var currentMusicTrack: String?

    public var musicVolume: Float = 0.5 {
        didSet { musicPlayer?.volume = musicVolume }
    }

    public var sfxVolume: Float = 0.7
    public var isMuted: Bool = false

    private init() {}

    // MARK: - Music

    public func playMusic(named track: String, fadeIn: Bool = true) {
        guard track != currentMusicTrack else { return }
        stopMusic(fadeOut: fadeIn)
        currentMusicTrack = track

        // In a real implementation, load from bundle
        // For now, this is a placeholder that supports the API
        guard let url = Bundle.main.url(forResource: track, withExtension: "mp3") else {
            return
        }

        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = -1 // Loop forever
            musicPlayer?.volume = fadeIn ? 0 : musicVolume
            musicPlayer?.play()

            if fadeIn {
                fadeInMusic()
            }
        } catch {
            // Music file not found - silently continue (placeholder assets)
        }
    }

    public func stopMusic(fadeOut: Bool = true) {
        guard let player = musicPlayer else { return }
        if fadeOut {
            fadeOutMusic { [weak self] in
                player.stop()
                self?.musicPlayer = nil
                self?.currentMusicTrack = nil
            }
        } else {
            player.stop()
            musicPlayer = nil
            currentMusicTrack = nil
        }
    }

    private func fadeInMusic() {
        guard let player = musicPlayer else { return }
        player.volume = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.musicPlayer else {
                timer.invalidate()
                return
            }
            player.volume += 0.05
            if player.volume >= self.musicVolume {
                player.volume = self.musicVolume
                timer.invalidate()
            }
        }
    }

    private func fadeOutMusic(completion: @escaping () -> Void) {
        guard let player = musicPlayer else {
            completion()
            return
        }
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            player.volume -= 0.05
            if player.volume <= 0 {
                timer.invalidate()
                completion()
            }
        }
    }

    // MARK: - Sound Effects

    public func playSFX(named name: String) {
        guard !isMuted else { return }
        // SFX are played via SKAction in the scene for SpriteKit integration
        // This method is for non-scene sounds
    }
}
