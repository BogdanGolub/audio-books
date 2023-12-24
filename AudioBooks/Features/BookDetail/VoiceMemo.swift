//
//  VoiceMemo.swift
//  AudioBooks
//
//  Created by Bohdan on 14.12.2023.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct VoiceMemo {
    struct State: Equatable, Identifiable {
        @PresentationState var alert: AlertState<Action.Alert>?
        
        var id: URL { self.current.id }
        var current: CurrentPlayback
        var mode = Mode.notPlaying
        var isReaderEnabled: Bool = false
        
        var songs: IdentifiedArrayOf<VoiceMemo.State.Song>
        var rate: Rates = .xOne
        let allRates: [Rates] = Rates.allCases
        
        init(songs: IdentifiedArrayOf<VoiceMemo.State.Song>) {
            self.songs = songs
            
            if let song = songs.first {
                self.current = .init(title: song.title,
                                     image: song.image,
                                     index: 0,
                                     url: song.url,
                                     duration: 0,
                                     currentTime: 0,
                                     backwardAvailable: false,
                                     forwardAvailable: songs.endIndex - 1 != 0)
            } else {
                self.current = .init(title: "",
                                     image: "",
                                     index: 0,
                                     url: .temporaryDirectory,
                                     duration: 0,
                                     currentTime: 0, 
                                     backwardAvailable: false,
                                     forwardAvailable: false)
            }
        }
        
        @CasePathable
        @dynamicMemberLookup
        enum Mode: Equatable {
            case notPlaying
            case playing(progress: Double)
        }
        
        struct CurrentPlayback: Equatable, Identifiable {
            var title: String
            var image: String
            var index: Int
            var url: URL
            var duration: TimeInterval
            var currentTime: TimeInterval
            var slide: TimeInterval = 0
            var isSeekInProgress: Bool? = false // nil for avoiding jumping slider from old player value to slide value
            var backwardAvailable: Bool
            var forwardAvailable: Bool
            var id: URL { self.url }
        }
        
        struct Song: Equatable, Identifiable {
            
            var id: URL { self.url }
            let title: String
            let url: URL
            let image: String
            
            init(title: String, resourceName: String, image: String) {
                self.title = title
                self.url = Bundle.main.url(forResource: resourceName, withExtension: "aac")!
                self.image = image
            }
        }
        
        enum Rates: Float, CaseIterable, Identifiable {
            
            var id: Self { self }
            
            case xOne = 1
            case xOneHalf = 1.5
            case xTwo = 2
            case xTwoHalf = 2.5
            
            var next: Rates {
                switch self {
                case .xOne:
                    return .xOneHalf
                case .xOneHalf:
                    return .xTwo
                case .xTwo:
                    return .xTwoHalf
                case .xTwoHalf:
                    return .xOne
                }
            }
            
            var title: String {
                switch self {
                case .xOne:
                    return "Speed x1"
                case .xOneHalf:
                    return "Speed x1.5"
                case .xTwo:
                    return "Speed x2"
                case .xTwoHalf:
                    return "Speed x2.5"
                }
            }
        }
    }
    
    enum Action {
        case alert(PresentationAction<Alert>)
        case audioPlayerClient(Result<(Bool, TimeInterval, TimeInterval), Error>)
        case playButtonTapped
        case timerUpdated(TimeInterval)
        case slide(TimeInterval)
        case titleTextFieldChanged(String)
        case playbackStarted
        case playbackFailed
        case isReaderEnabled(Bool)
        case onEditingChanged(Bool)
        case clearSeek
        case changeRate
        case next
        case backward
        case nextFive
        case backwardFive
        
        enum Alert: Equatable {}
    }
    
    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.continuousClock) var clock
    private enum CancelID { case play }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .nextFive:
                return seekFive(state: &state, isForward: true)
            case .backwardFive:
                return seekFive(state: &state, isForward: false)
            case .backward:
                return move(state: &state, isForward: false)
            case .next:
                return move(state: &state, isForward: true)
            case .changeRate:
                state.rate = state.rate.next
                return .run { [rate = state.rate] send in
                    let _ = try await self.audioPlayer.rate(rate.rawValue)
                }
            case let .slide(time):
                let sharedEffect = self.sharedComputation(state: &state, time: time)
                state.current.slide = time
                return sharedEffect
                
            case .clearSeek:
                state.current.isSeekInProgress = nil
                return .none
            case let .onEditingChanged(editing):
                state.current.isSeekInProgress = editing
                
                if editing {
                    return .none
                } else {
                    return .run { [slide = state.current.slide] send in
                        let _ = try await self.audioPlayer.seek(slide)
                        await send(.clearSeek)
                    }
                }
            case let .isReaderEnabled(enabled):
                state.isReaderEnabled = enabled
                return .none
            case .playbackFailed:
                state.alert = AlertState { TextState("Voice memo playback failed.") }
                return .none
            case .playbackStarted:
                //              for memoID in state.voiceMemos.ids where memoID != id {
                //                state.voiceMemos[id: memoID]?.mode = .notPlaying
                //              }
                return .none
            case .alert:
                return .none
            case .audioPlayerClient(.failure):
                state.mode = .notPlaying
                return .merge(
                    .cancel(id: CancelID.play),
                    .send(.playbackFailed)
                )
                
            case .audioPlayerClient(.success((let success, let progress, let duration))):
                state.current.duration = duration
                if success {
                    state.mode = .notPlaying
                    state.current.duration = duration
                    return .cancel(id: CancelID.play)
                } else if state.current.isSeekInProgress == false || state.current.isSeekInProgress == nil {
                    return .send(.timerUpdated(progress))
                } else {
                    return .none
                }
                
            case .playButtonTapped:
                switch state.mode {
                case .notPlaying:
                    state.mode = .playing(progress: 0)
                    
                    return .run { [url = state.current.url, rate = state.rate] send in
                        await send(.playbackStarted)
                        
                        //                        async let playAudio: Void = send(
                        //                            .audioPlayerClient(Result { try await self.audioPlayer.play(url) })
                        //                        )
                        let playerStream = try await self.audioPlayer.play(url: url, rate: rate.rawValue)
                        
                        //                        var start: TimeInterval = 0
                        //                        for await _ in self.clock.timer(interval: .milliseconds(500)) {
                        //                            start += 0.5
                        //                            await send(.timerUpdated(start))
                        //                        }
                        
                        for try await item in playerStream {
                            await send(.audioPlayerClient(.success(item)))
                        }
                        
                        //                        await playAudio
                    }
                    .cancellable(id: CancelID.play, cancelInFlight: true)
                    
                case .playing:
                    state.mode = .notPlaying
                    return .cancel(id: CancelID.play)
                }
                
            case let .timerUpdated(time):
                //                guard !state.isSeekInProgress else { return .none }
                let sharedEffect = self.sharedComputation(state: &state, time: time)
                return sharedEffect
                
            case let .titleTextFieldChanged(text):
                state.current.title = text
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
    
    func seekFive(state: inout State, isForward: Bool) -> Effect<Action> {
        if isForward {
            let newTime = (state.current.currentTime + 10) > state.current.duration ? state.current.duration : (state.current.currentTime + 10)
            return .concatenate(.send(.onEditingChanged(true)),
                                .send(.slide(newTime)),
                                .send(.onEditingChanged(false)))
        } else {
            let newTime = (state.current.currentTime - 5) < 0 ? 0 : (state.current.currentTime - 5)
            return .concatenate(.send(.onEditingChanged(true)),
                                .send(.slide(newTime)),
                                .send(.onEditingChanged(false)))
        }
    }
    
    func move(state: inout State, isForward: Bool) -> Effect<Action> {
        let nextIndex: Int?
        if isForward {
            nextIndex = state.songs.endIndex - 1 != state.current.index ? state.songs.index(after: state.current.index) : nil
        } else {
            nextIndex = state.songs.startIndex != state.current.index ? state.songs.index(before: state.current.index) : nil
        }
        
        guard let nextIndex else { return .none }
        
        let song = state.songs[nextIndex]
        state.current = .init(title: song.title, 
                              image: song.image,
                              index: nextIndex,
                              url: song.url,
                              duration: 0,
                              currentTime: 0,
                              backwardAvailable: state.songs.startIndex != nextIndex,
                              forwardAvailable: state.songs.endIndex - 1 != nextIndex)
        let isPlaying = state.mode != State.Mode.notPlaying
        state.mode = .notPlaying
        return isPlaying ? .concatenate(.cancel(id: CancelID.play), .send(.playButtonTapped)) : .none
    }
    
    func sharedComputation(state: inout State, time: TimeInterval) -> Effect<Action> {
        
        guard state.current.isSeekInProgress != nil else {
            state.current.isSeekInProgress = false
            return .none
        }
        
        switch state.mode {
        case .notPlaying:
            state.current.currentTime = 0
        case .playing:
            //                    state.mode = .playing(progress: time / state.duration)
            let currentTime = time > state.current.duration ? state.current.duration : time
            
            state.current.currentTime = currentTime
            state.mode = .playing(progress: currentTime)
        }
        return .none
    }
}

struct ContentView: View {
    
    let store: StoreOf<VoiceMemo>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                
                Image(viewStore.current.image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.bottom, 16)
                
                Spacer()
                
                Text("KEY POINT \(viewStore.current.index + 1) OF \(viewStore.songs.count)")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.bottom, 8)
                
                Text(viewStore.current.title)
                    .multilineTextAlignment(.center)
                
                
                HStack(spacing: 0) {
                    dateComponentsFormatter.string(from: viewStore.mode.playing ?? 0).map {
                        Text($0)
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(Color(.systemGray))
                    }
                    Slider(value: viewStore.binding(get: \.current.currentTime, send: { .slide($0) }), in: 0...viewStore.current.duration, onEditingChanged: { editing in
                        viewStore.send(.onEditingChanged(editing))
                    })
                    .accentColor(Color(red: 42/255, green: 100/255, blue: 246/255))
                    .onAppear {
                        UISlider.appearance().setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
    //                    UISlider.appearance().setThumbTintColor(.red) // Set the thumb color to red
                    }
                    .padding(.horizontal)
                    dateComponentsFormatter.string(from: viewStore.current.duration).map {
                        Text($0)
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(Color(.systemGray))
                    }
                }
                .padding(.bottom, 4)
                
                Button(action: {
                    viewStore.send(.changeRate)
                }) {
                    Text(viewStore.rate.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.all, 6)
                        .background(.gray.opacity(0.3))
                        .cornerRadius(4)
                        .padding(.bottom, 40)
                }
                .buttonStyle(.plain)
                
                
                HStack(spacing: 36) {
                    Button(action: {
                        viewStore.send(.backward)
                    }) {
                        Image(systemName: "backward.end.fill")
                            .foregroundColor(.black)
                            .scaleEffect(1.2)
                    }
                    .opacity(!viewStore.current.backwardAvailable ? 0.3 : 1)
                    .disabled(!viewStore.current.backwardAvailable)
                    
                    Button(action: {
                        viewStore.send(.backwardFive)
                    }) {
                        Image(systemName: "gobackward.5")
                            .foregroundColor(.black)
                            .scaleEffect(1.5)
                    }
                    
                    Button(action: {
//                        viewStore.send(.playButtonTapped)
                        viewStore.send(.playbackFailed)
                    }) {
                        Image(systemName: viewStore.mode.is(\.playing) ? "pause.fill" : "play.fill" )
                            .foregroundColor(.black)
                            .scaleEffect(2)
                    }
                    
                    Button(action: {
                        viewStore.send(.nextFive)
                    }) {
                        Image(systemName: "goforward.10")
                            .foregroundColor(.black)
                            .scaleEffect(1.5)
                    }
                    
                    Button(action: {
                        viewStore.send(.next)
                    }) {
                        Image(systemName: "forward.end.fill")
                            .foregroundColor(.black)
                            .scaleEffect(1.2)
                    }
                    .opacity(!viewStore.current.forwardAvailable ? 0.3 : 1)
                    .disabled(!viewStore.current.forwardAvailable)
                }
                .padding(.bottom, 32)
                
                
                
                HStack {
                    ThumbToggle(status: viewStore.binding(get: \.isReaderEnabled, send: { .isReaderEnabled($0) }))
                }
            }
            .padding()
            .background(Color(red: 254/255, green: 248/255, blue: 244/255))
            .alert(store: self.store.scope(state: \.$alert, action: \.alert))
        }
    }
}

struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Your implementation
    }
}

#Preview {
    ContentView(store: Store(initialState: VoiceMemo.State(songs: [.init(title: "sample3",
                                                                         resourceName: "sample3",
                                                                         image: "sample3"),
                                                                   .init(title: "dwsample1-aac",
                                                                         resourceName: "dwsample1-aac",
                                                                         image: "dwsample1-aac")]),
                             reducer: {
        VoiceMemo()
    }))
}
