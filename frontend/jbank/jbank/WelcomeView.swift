import SwiftUI

struct WelcomeView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToRegistration = false
    @State private var navigateToOTP = false
    @State private var isExistingUser = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header Section
            VStack(spacing: 16) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("jBank")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Your secure banking companion")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Email Input Section
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your email address", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 4)
                }
                
                Button(action: handleContinue) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Continue")
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
                .disabled(email.isEmpty || isLoading)
                .opacity(email.isEmpty ? 0.6 : 1.0)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer
            Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
        .padding(.bottom, 40)
        .navigationTitle("Welcome")
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToRegistration) {
            RegistrationView(email: email)
        }
        .navigationDestination(isPresented: $navigateToOTP) {
            OTPVerificationView(
                email: email,
                firstName: "",
                lastName: ""
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleContinue() {
        // Prevent accidental double taps
        guard !isLoading else {
            print("[DEBUG] Button tapped while already loading. Ignoring.")
            return
        }
        
        print("[DEBUG] handleContinue tapped.")
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            showError = true
            print("[DEBUG] Invalid email.")
            return
        }
        
        isLoading = true
        print("[DEBUG] isLoading set to true. Starting Task.")
        
        Task {
            do {
                print("[DEBUG] Calling SupabaseManager.shared.generateOTP...")
                let response = try await SupabaseManager.shared.generateOTP(
                    email: email,
                    firstName: nil,
                    lastName: nil
                )
                print("[DEBUG] Received response from Supabase: \(response)")
                
                await MainActor.run {
                    isLoading = false
                    print("[DEBUG] isLoading set to false on main thread.")
                    
                    if response.isExistingUser {
                        print("[DEBUG] User is existing. Attempting to navigate to OTP screen.")
                        isExistingUser = true
                        navigateToOTP = true
                    } else {
                        print("[DEBUG] User is new. Attempting to navigate to Registration screen.")
                        navigateToRegistration = true
                    }
                    print("[DEBUG] State after setting navigation: navigateToOTP=\(navigateToOTP), navigateToRegistration=\(navigateToRegistration)")
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                    print("[DEBUG] Caught an error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    // The NavigationStack is now in ContentView, so we don't need it here for previews
    WelcomeView()
}
