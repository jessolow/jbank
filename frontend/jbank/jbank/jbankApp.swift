//
//  jbankApp.swift
//  jbank
//
//  Created by Jesse Low on 15/8/25.
//

import SwiftUI

@main
struct jbankApp: App {
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}
