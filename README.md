# AudioBooks — SwiftUI + The Composable Architecture

[![CI](https://github.com/BogdanGolub/audio-books/actions/workflows/ci.yml/badge.svg)](https://github.com/BogdanGolub/audio-books/actions/workflows/ci.yml)

A compact audiobook player built to explore **The Composable Architecture (TCA)** on top of SwiftUI. One `@Reducer` drives playback, seeking, chapter navigation and speed control, while the audio engine lives behind a `@DependencyClient`, so the feature can be exercised in previews and tests without touching AVFoundation.

Started as a take-home assignment (December 2023); revisited in 2026 to replace the template tests with real reducer tests (`TestStore`) and to run them on CI.

## Features

- Play / pause, previous & next chapter, skip back 5 s / forward 10 s
- Scrubbing with a *seek-in-progress* guard, so the slider never jumps back to a stale player time while you drag
- Playback speed cycling (1× → 1.5× → 2× → 2.5×)
- Automatic advance to the next chapter when the current one finishes
- Failures surface as an alert via `AlertState` / `@PresentationState`

## Architecture

```
AudioBooks
├── AudioBooksApp.swift                     # Store + root view
├── Features/BookDetail/BookDetail.swift    # @Reducer BookDetail — State, Action, body; ContentView
├── AudioPlayerClient/
│   ├── AudioPlayerClient.swift             # @DependencyClient: load / seek / rate / resume / pause
│   └── LiveAudioPlayerClient.swift         # AVPlayer implementation (liveValue)
├── Helpers/
└── CustomToggle.swift
```

- `BookDetail` keeps the whole playback state in a single `State` value and expresses side effects as `Effect`s (`.run`, `.cancellable`, `.concatenate`, `.merge`).
- `AudioPlayerClient.load` returns an `AsyncThrowingStream<(finished, progress, duration)>`; the reducer folds the stream into UI state and restarts playback for the next chapter when it finishes.
- `previewValue` and the generated `testValue` keep SwiftUI previews and `TestStore` tests independent of real audio.

## Tests and CI

`AudioBooksTests` drives the `BookDetail` reducer through a `TestStore` with a controlled `AudioPlayerClient`: play/pause, seeking, speed changes, chapter navigation and the failure alert are asserted step by step, without a real player.

GitHub Actions ([ci.yml](.github/workflows/ci.yml)) builds the app and runs the unit tests on an iOS simulator on every push.

## Stack

Swift 5 language mode · SwiftUI · TCA 1.5 (`@Reducer`, `@DependencyClient`, `@CasePathable`) · AVFoundation · XCTest · GitHub Actions

## Running

Open `AudioBooks.xcodeproj` in Xcode 15 or newer, let SPM resolve the packages and run on an iOS 17 simulator. Sample audio files are bundled with the app.
