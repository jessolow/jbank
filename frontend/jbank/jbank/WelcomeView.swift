import SwiftUI
import Supabase

struct WelcomeView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var alertMessage = ""
    
    // For the new navigation flow
    @State private var navigateToCreateAccount = false
    @State private var navigateToPending = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header Section
            VStack(spacing: 16) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Welcome to Jesse's Bank")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enter your email to sign in or create an account.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Authentication Options
            VStack(spacing: 16) {
                // Google Sign-In Button
                Button(action: {
                    Task {
                        await handleGoogleSignIn()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                }
                
                // Email Input
                TextField("Email Address", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                Button(action: {
                    Task {
                        await handleContinue()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue with Email")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(email.isEmpty || isLoading)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
                                // Hidden NavigationLinks to control the flow
                    NavigationLink(destination: CreateAccountView(email: email), isActive: $navigateToCreateAccount) {
                        EmptyView()
                    }
                    
                    NavigationLink(destination: PendingMagicLinkView(email: email), isActive: $navigateToPending) {
                        EmptyView()
                    }
        }
        .padding(.top, 60)
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func handleGoogleSignIn() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await SupabaseManager.shared.signInWithGoogle()
            // Google OAuth will handle the redirect back to the app
            // The SessionManager will pick up the session automatically
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                alertMessage = "Google sign-in failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func handleContinue() async {
        print("[WelcomeView] handleContinue called.")
        guard !email.isEmpty else {
            print("[WelcomeView] Email is empty, returning.")
            return
        }
        
        await MainActor.run {
            print("[WelcomeView] Setting isLoading = true")
            isLoading = true
        }
        
        do {
            print("[WelcomeView] Checking if user exists for email: \(email)")
            let exists = try await SupabaseManager.shared.userExists(email: email)
            print("[WelcomeView] User exists check complete. Result: \(exists)")
            
            if exists {
                print("[WelcomeView] User exists. Sending magic link.")
                // Existing User: Send magic link and go to pending screen
                try await SupabaseManager.shared.sendMagicLink(to: email)
                print("[WelcomeView] Magic link sent. Navigating to pending screen.")
                await MainActor.run {
                    isLoading = false
                    navigateToPending = true
                }
            } else {
                print("[WelcomeView] User does not exist. Navigating to create account screen.")
                // New User: Go to create account screen
                await MainActor.run {
                    isLoading = false
                    navigateToCreateAccount = true
                }
            }
        } catch {
            print("[WelcomeView] --- ERROR ---")
            print("[WelcomeView] Error in handleContinue: \(error.localizedDescription)")
            print("[WelcomeView] Raw Error: \(error)")
            print("[WelcomeView] --- END ERROR ---")
            await MainActor.run {
                self.isLoading = false
                self.alertMessage = "An error occurred: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
}

#Preview {
    WelcomeView()
}
