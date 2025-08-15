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
            } else if sessionManager.needsProfileCompletion, let session = sessionManager.currentSession {
                // Google OAuth user needs to complete their profile
                NavigationStack {
                    GoogleProfileCompletionView(session: session)
                }
            } else if sessionManager.isLoggedIn {
                // User is logged in, show the main app content
                NavigationStack {
                    HomeView()
                }
            } else {
                // User is not logged in, show the welcome/onboarding flow
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
            // Use the primary background color of the current color scheme
            Color.primary.opacity(0.1).edgesIgnoringSafeArea(.all)
            
            VStack {
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
        .environmentObject(SessionManager())
}
