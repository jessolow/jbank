import Foundation
import Combine
import LocalAuthentication

@MainActor
class SessionManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var authError: String?

    private let authAccount = "currentUser" // A consistent key for keychain storage

    init() {
        // When the app starts, try to perform a biometric login
        Task {
            await tryBiometricLogin()
        }
    }

    private func tryBiometricLogin() async {
        // 1. Check if a token is saved in the keychain
        // We need an email to look up the token
        guard let email = UserDefaults.standard.string(forKey: "userEmail"),
              let token = KeychainManager.shared.read(for: email),
              let firstName = UserDefaults.standard.string(forKey: "userFirstName"),
              let lastName = UserDefaults.standard.string(forKey: "userLastName") else {
            // No saved token, proceed to normal welcome screen
            self.isLoading = false
            return
        }

        // 2. A token exists, so request biometric authentication
        let context = LAContext()
        let reason = "Sign in to your jBank account"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                // 3. Biometric scan successful!
                // In a real app, you would now validate this token with your server.
                // For now, we will assume it's valid and log the user in.
                let savedUser = User(id: "saved-user", email: email, firstName: firstName, lastName: lastName, isVerified: true, createdAt: "", updatedAt: "")
                self.currentUser = savedUser
                self.isLoggedIn = true
                self.isLoading = false
            } else {
                // User failed or cancelled the biometric scan
                self.isLoading = false
            }
        } catch {
            // Handle errors, e.g., biometrics not available or not set up
            print("Biometric login error: \(error.localizedDescription)")
            self.authError = "Biometric login failed. Please sign in manually."
            self.isLoading = false
        }
    }
    
    func login(sessionToken: String, user: User) {
        // After a successful manual login (e.g., OTP)
        // Note: Biometric setup will handle saving the token upon user consent
        self.currentUser = user
        self.isLoggedIn = true
        self.isLoading = false
        
        // Save user's basic info for the next session's biometric login
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        UserDefaults.standard.set(user.firstName, forKey: "userFirstName")
        UserDefaults.standard.set(user.lastName, forKey: "userLastName")
    }

    func logout() {
        // Clear session data from this manager
        self.isLoggedIn = false
        self.currentUser = nil
        
        // Use the email of the logged-out user to find the correct keychain entry
        if let email = UserDefaults.standard.string(forKey: "userEmail") {
            _ = KeychainManager.shared.delete(for: email)
        }
        
        // Clear the saved token from the keychain and user defaults
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userFirstName")
        UserDefaults.standard.removeObject(forKey: "userLastName")
        print("Session data and keychain token cleared.")
    }
}
