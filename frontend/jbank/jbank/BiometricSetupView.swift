import SwiftUI
import LocalAuthentication

struct BiometricSetupView: View {
    @EnvironmentObject var sessionManager: SessionManager // Access the session manager
    let user: User
    let sessionToken: String
    
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var biometricType: LABiometryType = .none
    @State private var isSetupComplete = false
    @State private var showSuccess = false
    @State private var navigateToHome = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header Section
            VStack(spacing: 16) {
                Image(systemName: biometricIcon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Secure Your Account")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(biometricDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Benefits Section
            VStack(spacing: 20) {
                Text("Why use \(biometricTypeName)?")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 16) {
                    BenefitRow(
                        icon: "shield.checkered",
                        title: "Enhanced Security",
                        description: "Your biometric data never leaves your device"
                    )
                    
                    BenefitRow(
                        icon: "bolt.fill",
                        title: "Lightning Fast",
                        description: "Access your account in an instant"
                    )
                    
                    BenefitRow(
                        icon: "hand.raised.fill",
                        title: "No Passwords",
                        description: "Never worry about forgetting your password again"
                    )
                }
            }
            .padding(.horizontal, 24)
            
            // Action Buttons
            VStack(spacing: 16) {
                Button(action: setupBiometric) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Set Up \(biometricTypeName)")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isLoading || biometricType == .none)
                .opacity(biometricType == .none ? 0.6 : 1.0)
                
                Button("Skip for Now") {
                    skipBiometric()
                }
                .foregroundColor(.secondary)
                .font(.body)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer
            Text("You can always set this up later in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)
        .padding(.bottom, 40)
        .navigationTitle("Security Setup")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            NavigationLink(
                destination: HomeView(user: user),
                isActive: $navigateToHome,
                label: { EmptyView() }
            )
        )
        .onAppear {
            checkBiometricType()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Setup Complete!", isPresented: $showSuccess) {
            Button("Continue to jBank") {
                navigateToHome = true
            }
        } message: {
            Text("Your \(biometricTypeName) is now set up. You can use it to sign in securely.")
        }
    }
    
    private var biometricIcon: String {
        switch biometricType {
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        default:
            return "lock.shield"
        }
    }
    
    private var biometricTypeName: String {
        switch biometricType {
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        default:
            return "Biometric"
        }
    }
    
    private var biometricDescription: String {
        switch biometricType {
        case .touchID:
            return "Set up Touch ID to sign in securely with your fingerprint"
        case .faceID:
            return "Set up Face ID to sign in securely with your face"
        default:
            return "Biometric authentication is not available on this device"
        }
    }
    
    private func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
            if let error = error {
                print("Biometric error: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupBiometric() {
        isLoading = true
        
        let context = LAContext()
        let reason = "Set up \(biometricTypeName) for secure sign-in"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    // Biometric setup successful, now save the session token
                    // Use the consistent key "currentUser" so our SessionManager can find it
                    let saveSuccess = KeychainManager.shared.save(token: sessionToken, for: user.email)
                    
                    if saveSuccess {
                        // Finally, log the user in
                        sessionManager.login(sessionToken: sessionToken, user: user)
                    } else {
                        // Handle failure to save the token
                        errorMessage = "Biometric setup was successful, but we couldn't save your session. Please try logging in again."
                        showError = true
                    }
                } else {
                    // Biometric setup failed
                    if let error = error {
                        errorMessage = "Setup failed: \(error.localizedDescription)"
                    } else {
                        errorMessage = "Biometric setup failed. Please try again."
                    }
                    showError = true
                }
            }
        }
    }
    
    private func skipBiometric() {
        // If the user skips, log them in without setting up biometrics
        sessionManager.login(sessionToken: sessionToken, user: user)
    }
}

// Benefit Row Component
struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// Placeholder HomeView (we'll create this next)
struct HomeView: View {
    @EnvironmentObject var sessionManager: SessionManager // For logout
    let user: User // Receive the full user object
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to jBank!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Hello, \(user.firstName)!")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Your account is now set up and secure.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            Button("Log Out") {
                sessionManager.logout()
            }
            .foregroundColor(.red)
            .padding()
        }
        .padding(.top, 60)
        .navigationTitle("jBank")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true) // Can't go back to setup
    }
}

#Preview {
    // The NavigationStack is now in ContentView, so we don't need it here for previews
    let dummyUser = User(id: "123", email: "user@example.com", firstName: "John", lastName: "Doe", isVerified: true, createdAt: "", updatedAt: "")
    BiometricSetupView(
        user: dummyUser,
        sessionToken: "dummy-session-token-for-preview" // Add dummy token
    )
    .environmentObject(SessionManager())
}
