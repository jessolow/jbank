import SwiftUI
import Supabase

struct HomeView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isDarkMode = true // Default to dark mode as per user preference
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Header Section
                VStack(spacing: 16) {
                    HStack {
                        // Welcome Message (Top Left)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome to Jesse's Bank")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            if let userProfile = sessionManager.userProfile {
                                if let displayName = userProfile.display_name, !displayName.isEmpty {
                                    Text(displayName)
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(userProfile.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Dark/Light Mode Toggle (Top Right)
                        Button(action: {
                            isDarkMode.toggle()
                            // This will be implemented to actually change the app's color scheme
                        }) {
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                .font(.title2)
                                .foregroundColor(isDarkMode ? .yellow : .blue)
                                .frame(width: 44, height: 44)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Navigation Buttons Row
                    HStack(spacing: 16) {
                        NavigationButton(
                            title: "Savings",
                            icon: "banknote.fill",
                            color: .green,
                            destination: SavingsView()
                        )
                        
                        NavigationButton(
                            title: "Credit",
                            icon: "creditcard.fill",
                            color: .blue,
                            destination: CreditView()
                        )
                        
                        NavigationButton(
                            title: "Loans",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .orange,
                            destination: LoansView()
                        )
                        
                        NavigationButton(
                            title: "Loyalty",
                            icon: "star.fill",
                            color: .purple,
                            destination: LoyaltyView()
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
                .background(Color.primary.opacity(0.05))
                
                // Main Content Area
                ScrollView {
                    VStack(spacing: 20) {
                        // Quick Overview Cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            QuickOverviewCard(
                                title: "Total Balance",
                                amount: "$12,450.67",
                                icon: "dollarsign.circle.fill",
                                color: .green
                            )
                            
                            QuickOverviewCard(
                                title: "Available Credit",
                                amount: "$8,500.00",
                                icon: "creditcard.fill",
                                color: .blue
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Recent Activity Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Activity")
                                .font(.headline)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<5) { index in
                                        RecentActivityCard(
                                            title: "Transaction \(index + 1)",
                                            amount: "$\(Double.random(in: 10...500).rounded(to: 2))",
                                            date: "Today",
                                            type: index % 2 == 0 ? .credit : .debit
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") {
                        Task {
                            await sessionManager.logout()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - Navigation Button Component
struct NavigationButton<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Overview Card Component
struct QuickOverviewCard: View {
    let title: String
    let amount: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(amount)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Recent Activity Card Component
struct RecentActivityCard: View {
    let title: String
    let amount: String
    let date: String
    let type: HomeTransactionType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(amount)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(type == .credit ? .green : .red)
            
            Text(date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 120, height: 80)
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(type == .credit ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Transaction Type Enum
enum HomeTransactionType {
    case credit
    case debit
}

// MARK: - Extension for Double Rounding
extension Double {
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}

#Preview {
    HomeView()
        .environmentObject(SessionManager())
}
