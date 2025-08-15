import SwiftUI

struct RegistrationView: View {
    let email: String
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToOTP = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Header Section
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Complete Your Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Tell us a bit about yourself")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Form Section
            VStack(spacing: 24) {
                // Email Display (Read-only)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text(email)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // First Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("First Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your first name", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 4)
                }
                
                // Last Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your last name", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 4)
                }
                
                // Submit Button
                Button(action: handleSubmit) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Create Account")
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
                .disabled(firstName.isEmpty || lastName.isEmpty || isLoading)
                .opacity((firstName.isEmpty || lastName.isEmpty) ? 0.6 : 1.0)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer
            Text("Your information is secure and encrypted")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)
        .padding(.bottom, 40)
        .navigationTitle("Registration")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToOTP) {
            OTPVerificationView(
                email: email,
                firstName: firstName,
                lastName: lastName
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleSubmit() {
        // Prevent accidental double taps
        guard !isLoading else { return }
        
        guard isValidInput() else { return }
        
        isLoading = true
        
        Task {
            do {
                // Generate OTP with user details via Supabase
                let response = try await SupabaseManager.shared.generateOTP(
                    email: email,
                    firstName: firstName,
                    lastName: lastName
                )
                
                await MainActor.run {
                    isLoading = false
                    
                    if response.success {
                        // Navigate to OTP verification screen
                        navigateToOTP = true
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
    
    private func isValidInput() -> Bool {
        if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your first name"
            showError = true
            return false
        }
        
        if lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your last name"
            showError = true
            return false
        }
        
        if firstName.count < 2 {
            errorMessage = "First name must be at least 2 characters"
            showError = true
            return false
        }
        
        if lastName.count < 2 {
            errorMessage = "Last name must be at least 2 characters"
            showError = true
            return false
        }
        
        return true
    }
}

#Preview {
    // The NavigationStack is now in ContentView, so we don't need it here for previews
    RegistrationView(email: "test@example.com")
}
