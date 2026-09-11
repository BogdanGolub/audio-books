//
//  AudioBooksTests.swift
//  AudioBooksTests
//
//  Reducer tests for BookDetail using TCA's TestStore.
//  The audio engine is replaced with in-memory closures, so no AVFoundation is involved.
//

import ComposableArchitecture
import XCTest
@testable import AudioBooks

@MainActor
final class BookDetailTests: XCTestCase {

    private struct PlayerError: Error, Equatable {}

    private var songs: IdentifiedArrayOf<BookDetail.State.Song> {
        [
            .init(title: "sample3", resourceName: "sample3", image: "sample3"),
            .init(title: "dwsample1-aac", resourceName: "dwsample1-aac", image: "dwsample1-aac"),
        ]
    }

    // MARK: - Play / pause

    func testPlayButtonTogglesPlaybackAndDrivesThePlayer() async {
        let resumedAt = LockIsolated<[TimeInterval]>([])
        let pauseCalls = LockIsolated(0)

        let store = TestStore(initialState: BookDetail.State(songs: songs)) {
            BookDetail()
        } withDependencies: {
            $0.audioPlayer.resume = { time in
                resumedAt.withValue { $0.append(time) }
                return true
            }
            $0.audioPlayer.pause = {
                pauseCalls.withValue { $0 += 1 }
                return true
            }
        }

        let play = await store.send(.playButtonTapped) {
            $0.mode = .playing(progress: 0)
        }
        await play.finish()
        XCTAssertEqual(resumedAt.value, [0])

        let pause = await store.send(.playButtonTapped) {
            $0.mode = .notPlaying
        }
        await pause.finish()
        XCTAssertEqual(pauseCalls.value, 1)
    }

    // MARK: - Playback rate

    func testChangeRateCyclesThroughAllRatesAndTellsThePlayer() async {
        let rates = LockIsolated<[Float]>([])

        let store = TestStore(initialState: BookDetail.State(songs: songs)) {
            BookDetail()
        } withDependencies: {
            $0.audioPlayer.rate = { rate in
                rates.withValue { $0.append(rate) }
                return true
            }
        }

        await store.send(.changeRate) { $0.rate = .xOneHalf }
        await store.send(.changeRate) { $0.rate = .xTwo }
        await store.send(.changeRate) { $0.rate = .xTwoHalf }
        await store.send(.changeRate) { $0.rate = .xOne }
        await store.finish()

        XCTAssertEqual(rates.value, [1.5, 2, 2.5, 1])
    }

    // MARK: - Chapter navigation

    func testNextMovesToTheLastChapterAndRestartsLoading() async {
        let loadedURLs = LockIsolated<[URL]>([])

        let store = TestStore(initialState: BookDetail.State(songs: songs)) {
            BookDetail()
        } withDependencies: {
            $0.audioPlayer.load = { url, _, _ in
                loadedURLs.withValue { $0.append(url) }
                return AsyncThrowingStream { $0.finish() }
            }
        }

        let last = songs[1]

        await store.send(.next) {
            $0.current = .init(
                title: last.title,
                image: last.image,
                index: 1,
                url: last.url,
                duration: 0,
                currentTime: 0,
                backwardAvailable: true,
                forwardAvailable: false
            )
        }
        await store.receive(\.onAppear)
        await store.finish()

        XCTAssertEqual(loadedURLs.value, [last.url])

        // Already on the last chapter: nothing happens.
        await store.send(.next)
    }

    func testBackwardOnFirstChapterDoesNothing() async {
        let store = TestStore(initialState: BookDetail.State(songs: songs)) {
            BookDetail()
        }

        await store.send(.backward)
    }

    // MARK: - Seeking

    func testSkipForwardRunsTheSeekPipeline() async {
        let seekedTo = LockIsolated<[TimeInterval]>([])

        var initialState = BookDetail.State(songs: songs)
        initialState.current.duration = 60
        initialState.current.currentTime = 20

        let store = TestStore(initialState: initialState) {
            BookDetail()
        } withDependencies: {
            $0.audioPlayer.seek = { time in
                seekedTo.withValue { $0.append(time) }
                return true
            }
        }

        await store.send(.nextFive)
        await store.receive(\.onEditingChanged) {
            $0.current.isSeekInProgress = true
        }
        await store.receive(\.slide) {
            $0.current.currentTime = 30
            $0.current.slide = 30
        }
        await store.receive(\.onEditingChanged) {
            $0.current.isSeekInProgress = false
        }
        await store.receive(\.clearSeek) {
            $0.current.isSeekInProgress = nil
        }

        XCTAssertEqual(seekedTo.value, [30])
    }

    func testSkipForwardIsClampedToDuration() async {
        var initialState = BookDetail.State(songs: songs)
        initialState.current.duration = 60
        initialState.current.currentTime = 55

        let store = TestStore(initialState: initialState) {
            BookDetail()
        } withDependencies: {
            $0.audioPlayer.seek = { _ in true }
        }

        await store.send(.nextFive)
        await store.receive(\.onEditingChanged) {
            $0.current.isSeekInProgress = true
        }
        await store.receive(\.slide) {
            $0.current.currentTime = 60
            $0.current.slide = 60
        }
        await store.receive(\.onEditingChanged) {
            $0.current.isSeekInProgress = false
        }
        await store.receive(\.clearSeek) {
            $0.current.isSeekInProgress = nil
        }
    }

    // MARK: - Progress & failures

    func testProgressUpdatesAreIgnoredWhileScrubbing() async {
        var initialState = BookDetail.State(songs: songs)
        initialState.current.duration = 60
        initialState.current.currentTime = 10
        initialState.current.isSeekInProgress = true

        let store = TestStore(initialState: initialState) {
            BookDetail()
        }

        // Player keeps reporting progress, but the slider is being dragged: state must not move.
        await store.send(.audioPlayerClient(.success((false, 15, 60))))
    }

    func testPlaybackFailureStopsPlayingAndShowsAnAlert() async {
        var initialState = BookDetail.State(songs: songs)
        initialState.mode = .playing(progress: 3)

        let store = TestStore(initialState: initialState) {
            BookDetail()
        }

        await store.send(.audioPlayerClient(.failure(PlayerError()))) {
            $0.mode = .notPlaying
        }
        await store.receive(\.playbackFailed) {
            $0.alert = AlertState { TextState("Voice memo playback failed.") }
        }
    }
}
