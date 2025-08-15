import Foundation

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    // Your Supabase project credentials
    private let supabaseURL = "https://navolchoccoxcjkkwkcb.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hdm9sY2hvY2NveGNqa2t3a2NiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNTM3MzgsImV4cCI6MjA3MDgyOTczOH0.Dlq4IqAqnKFhzUazMhVjgMCR5rvomDdrm9H4UtTnrbA"
    
    private init() {}
    
    // MARK: - OTP Generation
    
    func generateOTP(email: String, firstName: String?, lastName: String?) async throws -> OTPResponse {
        let url = "\(supabaseURL)/functions/v1/generate-otp"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "email": email,
            "firstName": firstName ?? "",
            "lastName": lastName ?? ""
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw SupabaseError.apiError(errorResponse?.error ?? "Unknown error")
        }
        
        let otpResponse = try JSONDecoder().decode(OTPResponse.self, from: data)
        return otpResponse
    }
    
    // MARK: - OTP Verification
    
    func verifyOTP(email: String, otpCode: String) async throws -> VerificationResponse {
        let url = "\(supabaseURL)/functions/v1/verify-otp"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "email": email,
            "otpCode": otpCode
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw SupabaseError.apiError(errorResponse?.error ?? "Unknown error")
        }
        
        let verificationResponse = try JSONDecoder().decode(VerificationResponse.self, from: data)
        return verificationResponse
    }
}

// MARK: - Response Models

struct OTPResponse: Codable {
    let success: Bool
    let message: String
    let isExistingUser: Bool
    let otp: String? // Only present in development
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case success, message, isExistingUser, otp, note
    }
}

struct VerificationResponse: Codable {
    let success: Bool
    let message: String
    let user: User
    let sessionToken: String
    let expiresAt: String
    let note: String?
}

struct ErrorResponse: Codable {
    let error: String
}

struct User: Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let isVerified: Bool
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Error Types

enum SupabaseError: Error, LocalizedError {
    case networkError(String)
    case apiError(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError(let message):
            return "Data error: \(message)"
        }
    }
}
