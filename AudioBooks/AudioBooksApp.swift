//
//  AudioBooksApp.swift
//  AudioBooks
//
//  Created by Bohdan on 13.12.2023.
//

import SwiftUI
import ComposableArchitecture

@main
struct AudioBooksApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(initialState: VoiceMemo.State(date: Date(), duration: 5, url: Bundle.main.url(forResource: "sample3_out", withExtension: "aac")!, currentTime: 0)) {
                    VoiceMemo()._printChanges()
                }
            )
        }
    }
}
