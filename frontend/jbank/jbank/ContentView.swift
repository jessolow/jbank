//
//  ContentView.swift
//  jbank
//
//  Created by Jesse Low on 15/8/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        ZStack {
            if sessionManager.isLoading {
                // Show a loading/splash screen while we check for a session
                LoadingView()
            } else if sessionManager.isLoggedIn, let user = sessionManager.currentUser {
                // User is logged in, show the main app content
                // We wrap HomeView in its own NavigationView for proper titles and logout buttons
                NavigationView {
                    HomeView(user: user)
                }
            } else {
                // User is not logged in, show the welcome/onboarding flow
                // Use NavigationStack for modern navigation
                NavigationStack {
                    WelcomeView()
                }
            }
        }
    }
}

// A simple loading view for the splash screen
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            VStack {
                // Use a system image as a placeholder for the logo
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding(.top, 20)
            }
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(SessionManager()) // Add for preview
}
