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
            ContentView(store: Store(initialState: BookDetail.State(songs: [.init(title: "sample3",
                                                                                 resourceName: "sample3",
                                                                                 image: "sample3"),
                                                                           .init(title: "dwsample1-aac",
                                                                                 resourceName: "dwsample1-aac",
                                                                                 image: "dwsample1-aac")]),
                                     reducer: {
                BookDetail()
                    ._printChanges()
            }))
        }
    }
}
