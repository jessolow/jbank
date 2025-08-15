import SwiftUI
import Supabase

struct LoansView: View {
    @State private var loansData: [LoanData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading loans data...")
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
                                await loadLoansData()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else if !loansData.isEmpty {
                    // Loans Overview
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title)
                                .foregroundColor(.orange)
                            Text("My Loans")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        // Total Loans Summary
                        VStack(spacing: 12) {
                            Text("Total Outstanding")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                                                Text("$\(String(format: "%.2f", totalOutstanding))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                        )
                        
                        // Individual Loans
                        VStack(spacing: 16) {
                            Text("Active Loans")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(loansData, id: \.id) { loan in
                                LoanCard(loan: loan)
                            }
                        }
                        .padding(20)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // No Loans
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        Text("No Active Loans")
                            .font(.headline)
                        Text("You don't have any active loans at the moment.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
        }
        .navigationTitle("Loans")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadLoansData()
        }
    }
    
    private var totalOutstanding: Double {
        loansData.reduce(0) { $0 + $1.outstandingBalance }
    }
    
    private func loadLoansData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch data from Supabase backend
            let data = try await SupabaseManager.shared.fetchLoansData()
            await MainActor.run {
                self.loansData = data
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
struct LoanCard: View {
    let loan: LoanData
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.loanType.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Account: \(loan.accountNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                                                Text("$\(String(format: "%.2f", loan.outstandingBalance))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Outstanding")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interest Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                                                Text("\(String(format: "%.2f", loan.interestRate))%")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Payment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                                                Text("$\(String(format: "%.2f", loan.monthlyPayment))")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Due Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(loan.nextPaymentDate)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationView {
        LoansView()
    }
}
