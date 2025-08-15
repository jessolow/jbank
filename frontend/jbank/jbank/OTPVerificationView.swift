import SwiftUI

struct OTPVerificationView: View {
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
                            onCommit: {
                                if index < 5 && !otp[index].isEmpty {
                                    // Move to next field
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        // Focus next field logic would go here
                                    }
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
        .background(
            NavigationLink(
                destination: BiometricSetupView(
                    email: email,
                    firstName: firstName,
                    lastName: lastName
                ),
                isActive: $navigateToBiometric,
                label: { EmptyView() }
            )
        )
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
                navigateToBiometric = true
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(text.isEmpty ? Color.gray.opacity(0.3) : Color.blue, lineWidth: 2)
            )
            .onChange(of: text) { newValue in
                // Limit to single digit
                if newValue.count > 1 {
                    text = String(newValue.prefix(1))
                }
                // Only allow numbers
                text = newValue.filter { $0.isNumber }
                
                if !newValue.isEmpty {
                    onCommit()
                }
            }
    }
}

#Preview {
    NavigationView {
        OTPVerificationView(
            email: "user@example.com",
            firstName: "John",
            lastName: "Doe"
        )
    }
}
