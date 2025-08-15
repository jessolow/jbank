import SwiftUI

struct OTPVerificationView: View {
    @EnvironmentObject var sessionManager: SessionManager // Access the session manager
    let email: String
    let firstName: String
    let lastName: String
    
    @State private var otp = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var timeRemaining = 300 // 5 minutes in seconds
    @State private var canResend = false
    @State private var navigateToBiometric = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var verifiedSessionToken: String?
    @State private var verifiedUser: User? // Store the verified user
    
    // 1. Add FocusState to manage which field is active
    @FocusState private var focusedField: Int?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 32) {
            // Header Section
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Verify Your Email")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("We've sent a verification code to")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(email)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            // OTP Input Section
            VStack(spacing: 24) {
                Text("Enter the 6-digit code")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // OTP Input Fields
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        OTPTextField(
                            text: $otp[index],
                            index: index,
                            isFocused: $focusedField, // Pass the binding with '$'
                            onCommit: {
                                if index < 5 {
                                    focusedField = index + 1 // Move to next field
                                } else {
                                    focusedField = nil // All fields filled, dismiss keyboard
                                    verifyOTP()
                                }
                            }
                        )
                    }
                }
                
                // Timer and Resend
                VStack(spacing: 12) {
                    if timeRemaining > 0 {
                        Text("Code expires in \(timeString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Code expired")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button("Resend Code") {
                        resendOTP()
                    }
                    .disabled(!canResend)
                    .foregroundColor(canResend ? .blue : .gray)
                    .font(.body)
                }
                
                // Verify Button
                Button(action: verifyOTP) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Verify Email")
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
                .disabled(otp.joined().count < 6 || isLoading)
                .opacity(otp.joined().count < 6 ? 0.6 : 1.0)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer
            Text("Didn't receive the code? Check your spam folder")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)
        .padding(.bottom, 40)
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToBiometric) {
            // Ensure we have a user and token before navigating
            if let user = verifiedUser, let token = verifiedSessionToken {
                BiometricSetupView(
                    user: user,
                    sessionToken: token
                )
            }
        }
        .onAppear {
            // 2. Set the initial focus to the first field when the view appears
            focusedField = 0
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                canResend = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success!", isPresented: $showSuccess) {
            Button("Continue") {
                // Only navigate if we have a valid token
                if verifiedSessionToken != nil {
                    navigateToBiometric = true
                } else {
                    errorMessage = "Could not retrieve a valid session. Please try again."
                    showError = true
                }
            }
        } message: {
            Text(successMessage)
        }
    }
    
    private var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func verifyOTP() {
        let otpString = otp.joined()
        guard otpString.count == 6 else {
            errorMessage = "Please enter the complete 6-digit code"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Verify OTP via Supabase
                let response = try await SupabaseManager.shared.verifyOTP(
                    email: email,
                    otpCode: otpString
                )
                
                await MainActor.run {
                    isLoading = false
                    
                    if response.success {
                        // Save the user and token, then trigger the success alert
                        self.verifiedUser = response.user
                        self.verifiedSessionToken = response.sessionToken
                        
                        successMessage = "Email verified successfully! Welcome to jBank, \(response.user.firstName)!"
                        showSuccess = true
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func resendOTP() {
        Task {
            do {
                // Resend OTP via Supabase
                let response = try await SupabaseManager.shared.generateOTP(
                    email: email,
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName
                )
                
                await MainActor.run {
                    if response.success {
                        // Reset timer and OTP fields
                        timeRemaining = 300
                        canResend = false
                        otp = Array(repeating: "", count: 6)
                        
                        // Show success message
                        successMessage = "New verification code sent to \(email)"
                        showSuccess = true
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// Custom OTP Text Field
struct OTPTextField: View {
    @Binding var text: String
    let index: Int
    @FocusState.Binding var isFocused: Int? // Receive the focus state
    let onCommit: () -> Void
    
    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.title2)
            .fontWeight(.bold)
            .frame(width: 50, height: 50)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .focused($isFocused, equals: index) // Bind focus to this field's index
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused == index ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2) // Highlight when focused
            )
            .onChange(of: text) { newValue in
                // Limit to single digit
                let filtered = newValue.filter { $0.isNumber }
                if filtered.count > 1 {
                    text = String(filtered.prefix(1))
                } else {
                    text = filtered
                }
                
                if !text.isEmpty {
                    onCommit()
                }
            }
    }
}

#Preview {
    // The NavigationStack is now in ContentView, so we don't need it here for previews
    OTPVerificationView(
        email: "user@example.com",
        firstName: "John",
        lastName: "Doe"
    )
    .environmentObject(SessionManager()) // Add for preview
}
