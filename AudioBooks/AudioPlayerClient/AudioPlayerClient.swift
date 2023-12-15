//
//  AudioPlayerClient.swift
//  AudioBooks
//
//  Created by Bohdan on 14.12.2023.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct AudioPlayerClient {
    var play: @Sendable (_ url: URL, _ rate: Float) async throws -> AsyncThrowingStream<(Bool, TimeInterval, TimeInterval), Error>
    var seek: @Sendable (TimeInterval) async throws -> Bool
    var rate: @Sendable (Float) async throws -> Bool
}

extension AudioPlayerClient: TestDependencyKey {
    static let previewValue = Self(
        play: { _, _ in
            
            return AsyncThrowingStream { continuation in
                
                
                Task {
                    do {
                        try await Task.sleep(nanoseconds: 2_000_000)
                        continuation.yield((false, .zero, .zero))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }) { time in true
        } rate: { _ in true }
}

extension DependencyValues {
    var audioPlayer: AudioPlayerClient {
        get { self[AudioPlayerClient.self] }
        set { self[AudioPlayerClient.self] = newValue }
    }
}
