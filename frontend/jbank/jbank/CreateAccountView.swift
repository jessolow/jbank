import SwiftUI
import Supabase

struct CreateAccountView: View {
    @State private var displayName = ""
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var alertMessage = ""
    @State private var navigateToPending = false
    
    let email: String
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Text("Create Your Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Please provide a few more details to get started.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            // Input Fields
            VStack(spacing: 16) {
                TextField("Display Name", text: $displayName)
                    .textContentType(.name)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                TextField("Phone Number (Optional)", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            
            // Action Button
            Button(action: {
                Task {
                    await createAccount()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .disabled(displayName.isEmpty || isLoading)
            
            Spacer()
            
                                // Navigation
                    NavigationLink(destination: PendingMagicLinkView(email: email), isActive: $navigateToPending) {
                        EmptyView()
                    }
        }
        .padding(.top, 60)
        .navigationTitle("Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func createAccount() async {
        await MainActor.run { isLoading = true }
        
        var metadata = ["display_name": displayName]
        if !phoneNumber.isEmpty {
            metadata["phone_number"] = phoneNumber
        }
        
        do {
            try await SupabaseManager.shared.sendMagicLink(to: email, with: metadata)
            await MainActor.run {
                isLoading = false
                navigateToPending = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                alertMessage = "Failed to create account: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    NavigationView {
        CreateAccountView(email: "preview@example.com")
    }
}
