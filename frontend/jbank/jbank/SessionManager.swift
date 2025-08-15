import Foundation
import Combine
import Supabase

// MARK: - User Profile Model
struct UserProfile: Codable {
    let user_id: String
    let email: String
    let display_name: String?
    let phone_number: String?
}

@MainActor
class SessionManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = true
    @Published var currentSession: Session?
    @Published var needsProfileCompletion = false // For Google OAuth new users
    @Published var userProfile: UserProfile?

    private var authTask: Task<Void, Never>?

    init() {
        authTask = Task {
            for await (event, session) in SupabaseManager.shared.client.auth.authStateChanges {
                handleAuthStateChange(event: event, session: session)
            }
        }
    }
    
    deinit {
        authTask?.cancel()
    }

    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        print("Auth state changed: \(event)")
        
        // Update the session
        self.currentSession = session
        
        // For ANY authenticated session (including app startup), validate with backend
        if let session = session {
            print("[SessionManager] Session found - validating with backend")
            print("[SessionManager] Session user: \(session.user.email ?? "no email")")
            print("[SessionManager] User app metadata: \(session.user.appMetadata)")
            
            // Always validate any authenticated user with the backend
            Task {
                await self.validateUserWithBackend(user: session.user)
            }
        } else {
            print("[SessionManager] No session - user logged out")
            self.isLoggedIn = false
            self.needsProfileCompletion = false
            self.userProfile = nil
        }
        
        // We are no longer loading once we receive our first auth event
        if isLoading {
            isLoading = false
        }
    }
    
    func login(session: Session) {
        self.currentSession = session
        self.isLoggedIn = true
    }

    func logout() async {
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            print("Successfully signed out.")
        } catch {
            print("Sign out failed: \(error.localizedDescription)")
        }
        self.isLoggedIn = false
        self.currentSession = nil
        self.userProfile = nil
    }
    
    func setToLoggedOut() {
        self.isLoggedIn = false
        self.currentSession = nil
        self.isLoading = false
        self.userProfile = nil
    }
    
    private func validateUserWithBackend(user: User) async {
        guard let email = user.email else {
            print("[SessionManager] No email found for user")
            await MainActor.run {
                self.isLoggedIn = false
                self.needsProfileCompletion = false
            }
            return
        }
        
        print("[SessionManager] Validating user with backend: \(email)")
        print("[SessionManager] User ID: \(user.id)")
        print("[SessionManager] User created at: \(user.createdAt)")
        
        do {
            // Always use backend to determine user status regardless of auth method
            let userStatus = try await SupabaseManager.shared.checkOAuthUserStatus()
            print("[SessionManager] Backend user validation: \(userStatus)")
            
            await MainActor.run {
                // Store the user profile data
                self.userProfile = UserProfile(
                    user_id: userStatus.user_id,
                    email: userStatus.email,
                    display_name: userStatus.display_name,
                    phone_number: userStatus.phone_number
                )
                
                if userStatus.needs_profile_completion {
                    print("[SessionManager] Backend says: User needs profile completion")
                    self.needsProfileCompletion = true
                    self.isLoggedIn = false
                } else {
                    print("[SessionManager] Backend says: User profile is complete - login approved")
                    self.needsProfileCompletion = false
                    self.isLoggedIn = true
                }
            }
        } catch {
            print("[SessionManager] Error validating user with backend: \(error)")
            print("[SessionManager] Error details: \(error.localizedDescription)")
            
            // If the backend can't validate the user (e.g., user doesn't exist), sign them out
            await MainActor.run {
                print("[SessionManager] Backend validation failed - signing user out")
                Task {
                    await self.logout()
                }
            }
        }
    }
}
