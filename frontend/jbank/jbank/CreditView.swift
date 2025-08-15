import SwiftUI
import Supabase

struct CreditView: View {
    @State private var creditData: CreditData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading credit data...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Error loading data")
                            .font(.headline)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await loadCreditData()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else if let data = creditData {
                    CreditContentView(data: data)
                }
            }
        }
        .navigationTitle("Credit")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadCreditData()
        }
    }
    
    private func loadCreditData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch data from Supabase backend
            let data = try await SupabaseManager.shared.fetchCreditData()
            await MainActor.run {
                self.creditData = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Credit Content View
struct CreditContentView: View {
    let data: CreditData
    
    var body: some View {
        VStack(spacing: 16) {
            // Credit Card Overview
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("Credit Card")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // Credit Card Display
            VStack(spacing: 16) {
                HStack {
                    Text("Available Credit")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text("$\(String(format: "%.2f", data.availableCredit))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                
                HStack {
                    Text("Credit Limit: $\(String(format: "%.2f", data.creditLimit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Used: \(String(format: "%.1f", data.creditUtilization))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            )
            
            // Credit Details
            VStack(spacing: 16) {
                DetailRow(title: "Card Number", value: "•••• •••• •••• \(data.lastFourDigits)")
                DetailRow(title: "Expiry Date", value: data.expiryDate)
                DetailRow(title: "Interest Rate", value: "\(String(format: "%.2f", data.interestRate))%")
                DetailRow(title: "Minimum Payment", value: "$\(String(format: "%.2f", data.minimumPayment))")
                DetailRow(title: "Payment Due Date", value: data.paymentDueDate)
            }
            .padding(20)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
            
            // Recent Transactions
            VStack(alignment: .leading, spacing: 16) {
                Text("Recent Transactions")
                    .font(.headline)
                
                ForEach(data.recentTransactions, id: \.id) { transaction in
                    CreditTransactionRow(transaction: transaction)
                }
            }
            .padding(20)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Supporting Views
struct CreditTransactionRow: View {
    let transaction: CreditTransaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.body)
                    .fontWeight(.medium)
                Text(transaction.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("-$\(String(format: "%.2f", transaction.amount))")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                Text(transaction.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        CreditView()
    }
}
