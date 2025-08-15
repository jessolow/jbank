import Foundation
import Supabase

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        let supabaseURL = URL(string: "https://navolchoccoxcjkkwkcb.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hdm9sY2hvY2NveGNqa2t3a2NiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNTM3MzgsImV4cCI6MjA3MDgyOTczOH0.Dlq4IqAqnKFhzUazMhVjgMCR5rvomDdrm9H4UtTnrbA"
        
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }
    
    // MARK: - Auth Functions
    
    @MainActor
    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "jbank://login-callback")
        )
    }
    
    struct OAuthUserResponse: Codable {
        let user_id: String
        let email: String
        let is_first_time: Bool
        let needs_profile_completion: Bool
        let display_name: String?
        let phone_number: String?
    }
    
    struct ProfileCompletionResponse: Codable {
        let success: Bool
        let message: String?
        let error: String?
        let user_id: String?
        let display_name: String?
    }
    
    @MainActor
    func checkOAuthUserStatus() async throws -> OAuthUserResponse {
        print("[SupabaseManager] Checking OAuth user status...")
        
        struct EmptyRequest: Codable {} // For empty body
        
        let response: OAuthUserResponse = try await client.functions
            .invoke("handle-oauth-user", options: FunctionInvokeOptions(body: EmptyRequest()))
        
        print("[SupabaseManager] OAuth user status: \(response)")
        return response
    }
    
    @MainActor
    func completeProfile(displayName: String, phoneNumber: String) async throws {
        print("[SupabaseManager] Completing profile with name: \(displayName)")
        
        // Check if we have an authenticated user
        let currentUser = try await client.auth.user()
        print("[SupabaseManager] Current authenticated user: \(currentUser.email ?? "no email")")
        print("[SupabaseManager] User ID: \(currentUser.id)")
        
        // Get the current session to extract the access token
        let session = try await client.auth.session
        let accessToken = session.accessToken
        print("[SupabaseManager] Using access token: \(accessToken.prefix(20))...")
        
        struct ProfileRequest: Codable {
            let display_name: String
            let phone_number: String
        }
        
        let request = ProfileRequest(display_name: displayName, phone_number: phoneNumber)
        
        // Make direct HTTP request with the access token
        let url = URL(string: "https://navolchoccoxcjkkwkcb.supabase.co/functions/v1/complete-profile")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ProfileCompletion", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response"
            ])
        }
        
        if httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[SupabaseManager] HTTP error \(httpResponse.statusCode): \(errorString)")
            throw NSError(domain: "ProfileCompletion", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorString)"
            ])
        }
        
        let responseData = try JSONDecoder().decode(ProfileCompletionResponse.self, from: data)
        
        if !responseData.success {
            print("[SupabaseManager] Profile completion failed: \(responseData.error ?? "Unknown error")")
            throw NSError(domain: "ProfileCompletion", code: 1, userInfo: [
                NSLocalizedDescriptionKey: responseData.error ?? "Failed to complete profile"
            ])
        }
        
        print("[SupabaseManager] Profile completed successfully")
    }
    
    @MainActor
    func sendMagicLink(to email: String, with metadata: [String: String]? = nil) async throws {
        print("Attempting to send magic link to \(email)...")
        do {
            let mappedData: [String: AnyJSON]?
            if let metadata = metadata {
                mappedData = try metadata.reduce(into: [String: AnyJSON]()) { result, item in
                    result[item.key] = try AnyJSON(item.value)
                }
            } else {
                mappedData = nil
            }
            
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "jbank://login-callback"),
                data: mappedData
            )

            print("Successfully requested magic link from Supabase. Please check your Supabase Auth logs.")
        } catch {
            print("---")
            print(">>> SUPABASE CLIENT ERROR: Failed to send magic link.")
            print(">>> Localized Description: \(error.localizedDescription)")
            print(">>> Raw Error Details: \(error)")
            print("---")
            throw error // rethrow the error so the UI can still handle it
        }
    }
    
    // MARK: - User Management
    
    struct UserExistsResponse: Codable {
        let exists: Bool
    }
    
    func userExists(email: String) async throws -> Bool {
        print("[SupabaseManager] Checking if user exists: \(email)")
        
        struct EmailRequest: Codable {
            let email: String
        }
        
        let request = EmailRequest(email: email)
        let response: UserExistsResponse = try await client.functions
            .invoke("check-user-exists", options: FunctionInvokeOptions(body: request))
        
        print("[SupabaseManager] User exists response: \(response.exists)")
        return response.exists
    }
    
    @MainActor
    func handleDeepLink(_ url: URL, sessionManager: SessionManager) async {
        // Handle both custom URL schemes and Universal Links
        print("Handling deep link: \(url.absoluteString)")
        
        if url.absoluteString.contains("login-callback") || url.absoluteString.contains("callback") {
            do {
                let session = try await client.auth.session(from: url)
                sessionManager.login(session: session)
                print("Successfully authenticated user via deep link")
            } catch {
                print("Deep link login failed: \(error.localizedDescription)")
                sessionManager.setToLoggedOut()
            }
        }
    }
    
    @MainActor
    func getCurrentSession() async -> Session? {
        return try? await client.auth.session
    }
    
    // MARK: - Banking Data Fetching
    
    @MainActor
    func fetchSavingsData() async throws -> SavingsData {
        print("[SupabaseManager] Fetching savings data...")
        
        // For now, return mock data. Later this will fetch from Supabase backend
        // let response: SavingsData = try await client.functions
        //     .invoke("fetch-savings-data", options: FunctionInvokeOptions(body: EmptyRequest()))
        
        return SavingsData.mock
    }
    
    @MainActor
    func fetchCreditData() async throws -> CreditData {
        print("[SupabaseManager] Fetching credit data...")
        
        // For now, return mock data. Later this will fetch from Supabase backend
        // let response: CreditData = try await client.functions
        //     .invoke("fetch-credit-data", options: FunctionInvokeOptions(body: EmptyRequest()))
        
        return CreditData.mock
    }
    
    @MainActor
    func fetchLoansData() async throws -> [LoanData] {
        print("[SupabaseManager] Fetching loans data...")
        
        // For now, return mock data. Later this will fetch from Supabase backend
        // let response: [LoanData] = try await client.functions
        //     .invoke("fetch-loans-data", options: FunctionInvokeOptions(body: EmptyRequest()))
        
        return LoanData.mock
    }
    
    @MainActor
    func fetchLoyaltyData() async throws -> LoyaltyData {
        print("[SupabaseManager] Fetching loyalty data...")
        
        // For now, return mock data. Later this will fetch from Supabase backend
        // let response: LoyaltyData = try await client.functions
        //     .invoke("fetch-loyalty-data", options: FunctionInvokeOptions(body: EmptyRequest()))
        
        return LoyaltyData.mock
    }
    
    @MainActor
    func fetchHomeData() async throws -> HomeData {
        print("[SupabaseManager] Fetching home data...")
        
        // For now, return fresh mock data each time to demonstrate refresh functionality
        // Later this will fetch from Supabase backend
        // let response: HomeData = try await client.functions
        //     .invoke("fetch-home-data", options: FunctionInvokeOptions(body: EmptyRequest()))
        
        // Simulate network delay for realistic refresh experience
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Generate fresh mock data with current timestamp
        return HomeData(
            totalBalance: "$\(Double.random(in: 10000...20000).rounded(to: 2))",
            availableCredit: "$\(Double.random(in: 5000...15000).rounded(to: 2))",
            recentTransactions: [
                HomeTransaction(id: "1", title: "Salary Deposit", amount: "+$\(Double.random(in: 3000...6000).rounded(to: 2))", date: "Today", type: HomeTransactionType.credit),
                HomeTransaction(id: "2", title: "Grocery Store", amount: "-$\(Double.random(in: 50...200).rounded(to: 2))", date: "Today", type: HomeTransactionType.debit),
                HomeTransaction(id: "3", title: "Gas Station", amount: "-$\(Double.random(in: 30...80).rounded(to: 2))", date: "Yesterday", type: HomeTransactionType.debit),
                HomeTransaction(id: "4", title: "Interest Payment", amount: "+$\(Double.random(in: 20...50).rounded(to: 2))", date: "Yesterday", type: HomeTransactionType.credit),
                HomeTransaction(id: "5", title: "Restaurant", amount: "-$\(Double.random(in: 40...120).rounded(to: 2))", date: "2 days ago", type: HomeTransactionType.debit)
            ],
            lastUpdated: Date()
        )
    }
}
