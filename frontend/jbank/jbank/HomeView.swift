import SwiftUI
import Supabase

struct HomeView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        VStack(spacing: 20) {
            if let displayName = sessionManager.currentSession?.user.userMetadata["display_name"] as? String {
                Text("Welcome Back, \(displayName)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            } else {
                Text("Welcome to jBank")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            if let email = sessionManager.currentSession?.user.email {
                Text("You are logged in as:")
                    .font(.headline)
                Text(email)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Log Out") {
                Task {
                    await sessionManager.logout()
                }
            }
            .foregroundColor(.red)
            .padding()
        }
        .padding()
        .navigationTitle("Dashboard")
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    HomeView()
        .environmentObject(SessionManager())
}
