//
//  LiveAudioPlayerClient.swift
//  AudioBooks
//
//  Created by Bohdan on 14.12.2023.
//

@preconcurrency import AVFoundation
import Dependencies

extension AudioPlayerClient: DependencyKey {
    
    static let player = AVPlayer()
    
    static let liveValue = Self.init { url, rate, time in
        let stream = AsyncThrowingStream<(Bool, TimeInterval, TimeInterval), Error> { continuation in
            do {
                let delegate = try Delegate(player: AudioPlayerClient.player,
                    url: url, rate: rate, didUpdateProgress: { (progress, duration) in
                        continuation.yield((false, progress, duration))
                    },
                    didFinishPlaying: { duration in
                        continuation.yield((true, duration, duration))
                        continuation.finish()
                    },
                    decodeErrorDidOccur: { error in
                        continuation.finish(throwing: error)
                    }
                )
                let myTime = CMTime(seconds: time, preferredTimescale: 60000)
                delegate.player.seek(to: myTime, toleranceBefore: .zero, toleranceAfter: .zero)
//                delegate.player.play()
                continuation.onTermination = { status in
                    print("status \(status)")
                    delegate.player.pause()
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    } seek: { time in
        let myTime = CMTime(seconds: time, preferredTimescale: 60000)
        player.seek(to: myTime, toleranceBefore: .zero, toleranceAfter: .zero)
        return true
    } rate: { rate in
        player.playImmediately(atRate: rate)
        return true
    } resume: { time in
        let myTime = CMTime(seconds: time, preferredTimescale: 60000)
        player.seek(to: myTime, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
        return true
    } pause: {
        player.pause()
        return true
    }
// url in
        
        //        return try await stream.first(where: { _ in true }) ?? (false, TimeInterval(0), TimeInterval(0))
//    }, seek: { time in }
}

private final class Delegate: NSObject, AVAudioPlayerDelegate, Sendable {
    let didFinishPlaying: @Sendable (TimeInterval) -> Void
    let didUpdateProgress: @Sendable (TimeInterval, TimeInterval) -> Void
    let decodeErrorDidOccur: @Sendable (Error?) -> Void
    let player: AVPlayer
    
    init(
        player: AVPlayer,
        url: URL,
        rate: Float,
        didUpdateProgress: @escaping @Sendable (TimeInterval, TimeInterval) -> Void,
        didFinishPlaying: @escaping @Sendable (TimeInterval) -> Void,
        decodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
    ) throws {
        self.didUpdateProgress = didUpdateProgress
        self.didFinishPlaying = didFinishPlaying
        self.decodeErrorDidOccur = decodeErrorDidOccur
        self.player = player
        
        let item = AVPlayerItem(url: url)
        player.defaultRate = rate
        player.rate = rate
        player.replaceCurrentItem(with: item)
        player.pause()
        super.init()
        
        Task {
            let duration = await try? self.player.currentItem?.asset.load(.duration) ?? .zero
            
            await MainActor.run { [weak self] in
                self?.didUpdateProgress(0, duration?.seconds ?? .zero)
            }
        }
        
        
//        activateSession()
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main) {[weak self] (progressTime) in
//            print("periodic time: \(CMTimeGetSeconds(progressTime))")
            
            guard let self else { return }
            
            if self.player.currentItem?.status == .readyToPlay, progressTime.seconds > 0.05  {
                let currentTime = self.player.currentItem?.currentTime() ?? .zero
                let duration = self.player.currentItem?.duration ?? .zero
                self.didUpdateProgress(currentTime.seconds, duration.seconds)
            }
        }
        
        NotificationCenter.default.addObserver(self, 
                                               selector: #selector(playerDidFinishPlaying),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, 
                                               object: player.currentItem)
    }
    
    @objc func playerDidFinishPlaying(note: NSNotification) {
        let duration = player.currentItem?.duration ?? .zero
        self.didFinishPlaying(duration.seconds)
    }
}
