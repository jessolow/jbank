import SwiftUI
import Supabase
import UIKit

struct HomeView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isDarkMode = true // Default to dark mode as per user preference
    @State private var homeData = HomeData.mock
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?
    @State private var refreshTask: Task<Void, Never>?
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var isRefreshing = false
    
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
                                
                                if isLoading && isRefreshing {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Refreshing...")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else if isLoading {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading...")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Last updated: \(homeData.lastUpdated, style: .relative)")
                                        .font(.caption2)
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
                                amount: homeData.totalBalance,
                                icon: "dollarsign.circle.fill",
                                color: .green
                            )
                            
                            QuickOverviewCard(
                                title: "Available Credit",
                                amount: homeData.availableCredit,
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
                                    ForEach(homeData.recentTransactions, id: \.id) { transaction in
                                        RecentActivityCard(
                                            title: transaction.title,
                                            amount: transaction.amount,
                                            date: transaction.date,
                                            type: transaction.type
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    // Pull-to-refresh functionality: fetches fresh data from backend
                    // Only refresh if not already refreshing
                    if !isRefreshing {
                        // Create a new task for the refresh
                        let task = Task {
                            await refreshHomeData()
                        }
                        // Wait for the task to complete
                        await task.value
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
        .onAppear {
            // Cancel any existing load task
            loadTask?.cancel()
            
            // Start new load task
            loadTask = Task {
                await loadHomeData()
            }
        }
        .onDisappear {
            // Cancel any ongoing tasks when view disappears
            loadTask?.cancel()
            refreshTask?.cancel()
        }
    }
    
    private func loadHomeData() async {
        print("[HomeView] Starting to load home data...")
        do {
            let data = try await SupabaseManager.shared.fetchHomeData()
            
            // Check if task was cancelled
            try Task.checkCancellation()
            
            await MainActor.run {
                self.homeData = data
                print("[HomeView] Home data loaded successfully")
            }
        } catch is CancellationError {
            print("[HomeView] Home data load was cancelled")
        } catch {
            print("[HomeView] Failed to load home data: \(error)")
        }
    }
    
    private func refreshHomeData() async {
        print("[HomeView] Starting refresh...")
        
        // Prevent multiple simultaneous refreshes
        if isRefreshing {
            print("[HomeView] Refresh already in progress, skipping")
            return
        }
        
        // Debounce: prevent rapid successive refreshes
        let now = Date()
        if now.timeIntervalSince(lastRefreshTime) < 1.0 { // 1 second minimum between refreshes
            print("[HomeView] Refresh debounced - too soon since last refresh")
            return
        }
        
        // Cancel any existing refresh task
        refreshTask?.cancel()
        
        await MainActor.run {
            isLoading = true
            isRefreshing = true
            lastRefreshTime = now
        }
        
        // Small delay to stabilize the refresh gesture
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        do {
            let data = try await SupabaseManager.shared.fetchHomeData()
            
            // Check if task was cancelled
            try Task.checkCancellation()
            
            await MainActor.run {
                self.homeData = data
                self.isLoading = false
                self.isRefreshing = false
                print("[HomeView] Home data refresh completed successfully")
                
                // Provide haptic feedback for successful refresh
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        } catch is CancellationError {
            print("[HomeView] Home data refresh was cancelled")
            await MainActor.run {
                self.isLoading = false
                self.isRefreshing = false
            }
        } catch {
            print("[HomeView] Failed to refresh home data: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.isRefreshing = false
                
                // Provide haptic feedback for failed refresh
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            }
        }
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
