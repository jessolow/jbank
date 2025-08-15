import SwiftUI
import Supabase

struct GoogleProfileCompletionView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var displayName = ""
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var alertMessage = ""
    
    let session: Session // Passed from ContentView

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Text("Complete Your Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Welcome! Please provide a display name to finish setting up your account.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            // Input Fields
            VStack(spacing: 16) {
                TextField("Display Name", text: $displayName)
                    .textContentType(.name)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                TextField("Phone Number (Optional)", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            
            // Action Button
            Button(action: {
                Task {
                    await completeProfile()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Complete Profile")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .disabled(displayName.isEmpty || isLoading)
            
            Spacer()
        }
        .padding(.top, 60)
        .navigationTitle("Profile Setup")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // Prevent going back to WelcomeView
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func completeProfile() async {
        await MainActor.run { isLoading = true }
        
        do {
            try await SupabaseManager.shared.completeProfile(
                displayName: displayName,
                phoneNumber: phoneNumber
            )
            
            await MainActor.run {
                isLoading = false
                sessionManager.needsProfileCompletion = false
                sessionManager.isLoggedIn = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                alertMessage = "Failed to complete profile: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    // Mock session for preview
    let mockUser = User(
        id: UUID(),
        appMetadata: [:],
        userMetadata: [:],
        aud: "authenticated",
        confirmationSentAt: nil,
        recoverySentAt: nil,
        emailChangeSentAt: nil,
        newEmail: nil,
        invitedAt: nil,
        actionLink: nil,
        email: "preview@gmail.com",
        phone: nil,
        createdAt: Date(),
        confirmedAt: nil,
        emailConfirmedAt: nil,
        phoneConfirmedAt: nil,
        lastSignInAt: nil,
        role: nil,
        updatedAt: Date(),
        identities: [],
        isAnonymous: false,
        factors: []
    )
    let mockSession = Session(
        accessToken: "mock",
        tokenType: "bearer",
        expiresIn: 3600,
        expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970,
        refreshToken: "mock",
        user: mockUser
    )
    
    NavigationView {
        GoogleProfileCompletionView(session: mockSession)
            .environmentObject(SessionManager())
    }
}
