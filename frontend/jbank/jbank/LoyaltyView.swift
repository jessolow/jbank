import SwiftUI
import Supabase

struct LoyaltyView: View {
    @State private var loyaltyData: LoyaltyData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading loyalty data...")
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
                                await loadLoyaltyData()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else if let data = loyaltyData {
                    // Loyalty Program Overview
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.title)
                                .foregroundColor(.purple)
                            Text("Loyalty Program")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        // Points Summary Card
                        VStack(spacing: 12) {
                            Text("Total Points")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("\(data.totalPoints)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        )
                        
                        // Tier Information
                        VStack(spacing: 16) {
                            HStack {
                                Text("Current Tier")
                                    .font(.headline)
                                Spacer()
                                Text(data.currentTier.rawValue)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                            }
                            
                            // Progress Bar
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Progress to next tier")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(data.pointsToNextTier) points needed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                ProgressView(value: data.tierProgress, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                            }
                        }
                        .padding(20)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Available Rewards
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Rewards")
                                .font(.headline)
                            
                            ForEach(data.availableRewards, id: \.id) { reward in
                                RewardCard(reward: reward, userPoints: data.totalPoints)
                            }
                        }
                        .padding(20)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Recent Activity
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Activity")
                                .font(.headline)
                            
                            ForEach(data.recentActivity, id: \.id) { activity in
                                LoyaltyActivityRow(activity: activity)
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
        .navigationTitle("Loyalty")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadLoyaltyData()
        }
    }
    
    private func loadLoyaltyData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch data from Supabase backend
            let data = try await SupabaseManager.shared.fetchLoyaltyData()
            await MainActor.run {
                self.loyaltyData = data
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
struct RewardCard: View {
    let reward: LoyaltyReward
    let userPoints: Int
    
    var canRedeem: Bool {
        userPoints >= reward.pointsRequired
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(reward.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(reward.pointsRequired) pts")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(canRedeem ? .green : .red)
                
                Button(canRedeem ? "Redeem" : "Not Enough Points") {
                    // Handle redemption
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canRedeem)
                .scaleEffect(0.8)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(canRedeem ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

struct LoyaltyActivityRow: View {
    let activity: LoyaltyActivity
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.description)
                    .font(.body)
                    .fontWeight(.medium)
                Text(activity.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.points > 0 ? "+\(activity.points)" : "\(activity.points)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(activity.points > 0 ? .green : .red)
                Text("points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        LoyaltyView()
    }
}
