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
        var title = ""
        var image = ""
        var duration: TimeInterval = .zero
        var url: URL = .temporaryDirectory
        
        var mode = Mode.notPlaying
        var isPlayerEnabled: Bool = true
        var currentTime: TimeInterval = .zero
        var slide: TimeInterval = 0
        var isSeekInProgress: Bool? = false // nil for avoiding jumping slider from old player value to slide value
        var rate: Rates = .xOne
        
        var songs: IdentifiedArrayOf<VoiceMemo.State.Song>
        let allRates: [Rates] = Rates.allCases
        
        var id: URL { self.url }
        
        @CasePathable
        @dynamicMemberLookup
        enum Mode: Equatable {
            case notPlaying
            case playing(progress: Double)
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
        case isPlayerEnabled(Bool)
        case onEditingChanged(Bool)
        case clearSeek
        case setRate(State.Rates)
        case next
        case backward
        
        enum Alert: Equatable {}
    }
    
    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.continuousClock) var clock
    private enum CancelID { case play }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backward:
                return .none
            case .next:
                return .none
            case .setRate(let rate):
                state.rate = rate
                return .run { [rate = state.rate] send in
                    let _ = try await self.audioPlayer.rate(rate.rawValue)
                }
            case let .slide(time):
                let sharedEffect = self.sharedComputation(state: &state, time: time)
                state.slide = time
                return sharedEffect
                
            case .clearSeek:
                state.isSeekInProgress = nil
                return .none
            case let .onEditingChanged(editing):
                state.isSeekInProgress = editing
                
                if editing {
                    return .none
                } else {
                    return .run { [slide = state.slide] send in
                        let _ = try await self.audioPlayer.seek(slide)
                        await send(.clearSeek)
                    }
                }
            case let .isPlayerEnabled(enabled):
                state.isPlayerEnabled = enabled
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
                state.duration = duration
                if success {
                    state.mode = .notPlaying
                    state.duration = duration
                    return .cancel(id: CancelID.play)
                } else if state.isSeekInProgress == false || state.isSeekInProgress == nil {
                    return .send(.timerUpdated(progress))
                } else {
                    return .none
                }
                
            case .playButtonTapped:
                switch state.mode {
                case .notPlaying:
                    state.mode = .playing(progress: 0)
                    
                    return .run { [url = state.url, rate = state.rate] send in
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
                state.title = text
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
    
    func sharedComputation(state: inout State, time: TimeInterval) -> Effect<Action> {
        
        guard state.isSeekInProgress != nil else {
            state.isSeekInProgress = false
            return .none
        }
        
        switch state.mode {
        case .notPlaying:
            state.currentTime = 0
        case .playing:
            //                    state.mode = .playing(progress: time / state.duration)
            let currentTime = time > state.duration ? state.duration : time
            
            state.currentTime = currentTime
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
                
                Image("book")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.bottom, 16)
                
                Spacer()
                
                Text("KEY POINT 2 OF 10")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Design is not how a thing looks, but how it works")
                    .multilineTextAlignment(.center)
                
                
                HStack(spacing: 0) {
                    dateComponentsFormatter.string(from: viewStore.mode.playing ?? 0).map {
                        Text($0)
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(Color(.systemGray))
                    }
                    Slider(value: viewStore.binding(get: \.currentTime, send: { .slide($0) }), in: 0...viewStore.duration, onEditingChanged: { editing in
                        viewStore.send(.onEditingChanged(editing))
                    })
                    .padding(.horizontal)
                    dateComponentsFormatter.string(from: viewStore.duration).map {
                        Text($0)
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(Color(.systemGray))
                    }
                }
                
                
                Text(viewStore.rate.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.all, 6)
                    .background(.gray)
                    .cornerRadius(4)
                    .contextMenu {
                        
                        ForEach(viewStore.allRates) { rate in
                            Button {
                                viewStore.send(.setRate(rate))
                            } label: {
                                HStack {
                                    Text(rate.title)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                
                HStack(spacing: 30) {
                    Button(action: {
                        
                    }) {
                        Image(systemName: "backward.end")
                            .foregroundColor(.black)
                            .imageScale(.large)
                    }
                    
                    Button(action: {
                        
                    }) {
                        Image(systemName: "gobackward.5")
                            .foregroundColor(.black)
                            .imageScale(.large)
                    }
                    
                    Button(action: {
                        viewStore.send(.playButtonTapped)
                    }) {
                        Image(systemName: viewStore.mode.is(\.playing) ? "pause.fill" : "play.fill" )
                            .foregroundColor(.black)
                            .imageScale(.large)
                    }
                    
                    Button(action: {
                        
                    }) {
                        Image(systemName: "goforward.10")
                            .foregroundColor(.black)
                            .imageScale(.large)
                    }
                    
                    Button(action: {
                        
                    }) {
                        Image(systemName: "forward.end")
                            .foregroundColor(.black)
                            .imageScale(.large)
                    }
                }
                .padding(.bottom, 32)
                
                
                
                HStack {
                    ThumbToggle(status: viewStore.binding(get: \.isPlayerEnabled, send: { .isPlayerEnabled($0) }), backClose: .orange, backOpen: .black, thumbColor: .blue)
                }
            }
            .padding()
            .background(.white)
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
