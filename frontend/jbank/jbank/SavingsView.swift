import SwiftUI
import Supabase

struct SavingsView: View {
    @State private var savingsData: SavingsData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading savings data...")
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
                                await loadSavingsData()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else if let data = savingsData {
                    // Savings Account Overview
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "banknote.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            Text("Savings Account")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        // Account Balance Card
                        VStack(spacing: 12) {
                            Text("Current Balance")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                                                Text("$\(String(format: "%.2f", data.currentBalance))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                        
                        // Account Details
                        VStack(spacing: 16) {
                            DetailRow(title: "Account Number", value: data.accountNumber)
                            DetailRow(title: "Interest Rate", value: "\(String(format: "%.2f", data.interestRate))%")
                            DetailRow(title: "Monthly Interest", value: "$\(String(format: "%.2f", data.monthlyInterest))")
                            DetailRow(title: "Last Transaction", value: data.lastTransactionDate)
                        }
                        .padding(20)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Recent Transactions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Transactions")
                                .font(.headline)
                            
                            ForEach(data.recentTransactions, id: \.id) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                        .padding(20)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("Savings")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadSavingsData()
        }
    }
    
    private func loadSavingsData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch data from Supabase backend
            let data = try await SupabaseManager.shared.fetchSavingsData()
            await MainActor.run {
                self.savingsData = data
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

// MARK: - Supporting Views

struct TransactionRow: View {
    let transaction: SavingsTransaction
    
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
                Text(transaction.amount > 0 ? "+$\(String(format: "%.2f", transaction.amount))" : "-$\(String(format: "%.2f", abs(transaction.amount)))")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.amount > 0 ? .green : .red)
                Text(transaction.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        SavingsView()
    }
}
