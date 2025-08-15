import Foundation
import SwiftUI

// MARK: - Savings Data Models
struct SavingsData: Codable {
    let currentBalance: Double
    let accountNumber: String
    let interestRate: Double
    let monthlyInterest: Double
    let lastTransactionDate: String
    let recentTransactions: [SavingsTransaction]
}

struct SavingsTransaction: Codable {
    let id: String
    let description: String
    let amount: Double
    let date: String
    let type: SavingsTransactionType
}

enum SavingsTransactionType: String, Codable, CaseIterable {
    case deposit = "Deposit"
    case withdrawal = "Withdrawal"
    case interest = "Interest"
    case transfer = "Transfer"
}

// MARK: - Credit Data Models
struct CreditData: Codable {
    let availableCredit: Double
    let creditLimit: Double
    let creditUtilization: Double
    let lastFourDigits: String
    let expiryDate: String
    let interestRate: Double
    let minimumPayment: Double
    let paymentDueDate: String
    let recentTransactions: [CreditTransaction]
}

struct CreditTransaction: Codable {
    let id: String
    let description: String
    let amount: Double
    let date: String
    let category: TransactionCategory
}

enum TransactionCategory: String, Codable, CaseIterable {
    case dining = "Dining"
    case shopping = "Shopping"
    case travel = "Travel"
    case gas = "Gas"
    case groceries = "Groceries"
    case entertainment = "Entertainment"
    case other = "Other"
}

// MARK: - Loans Data Models
struct LoanData: Codable {
    let id: String
    let loanType: LoanType
    let accountNumber: String
    let outstandingBalance: Double
    let interestRate: Double
    let monthlyPayment: Double
    let nextPaymentDate: String
}

enum LoanType: String, Codable, CaseIterable {
    case personal = "Personal Loan"
    case mortgage = "Mortgage"
    case auto = "Auto Loan"
    case student = "Student Loan"
    case business = "Business Loan"
}

// MARK: - Loyalty Data Models
struct LoyaltyData: Codable {
    let totalPoints: Int
    let currentTier: LoyaltyTier
    let pointsToNextTier: Int
    let tierProgress: Double
    let availableRewards: [LoyaltyReward]
    let recentActivity: [LoyaltyActivity]
}

enum LoyaltyTier: String, Codable, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case diamond = "Diamond"
}

struct LoyaltyReward: Codable {
    let id: String
    let name: String
    let description: String
    let pointsRequired: Int
}

struct LoyaltyActivity: Codable {
    let id: String
    let description: String
    let points: Int
    let date: String
}

// MARK: - Mock Data for Development
extension SavingsData {
    static let mock = SavingsData(
        currentBalance: 12450.67,
        accountNumber: "SAV-2024-001",
        interestRate: 2.5,
        monthlyInterest: 25.94,
        lastTransactionDate: "2025-08-15",
        recentTransactions: [
            SavingsTransaction(id: "1", description: "Salary Deposit", amount: 5000.00, date: "2025-08-15", type: SavingsTransactionType.deposit),
            SavingsTransaction(id: "2", description: "Monthly Interest", amount: 25.94, date: "2025-08-01", type: SavingsTransactionType.interest),
            SavingsTransaction(id: "3", description: "ATM Withdrawal", amount: -200.00, date: "2025-08-15", type: SavingsTransactionType.withdrawal)
        ]
    )
}

extension CreditData {
    static let mock = CreditData(
        availableCredit: 8500.00,
        creditLimit: 15000.00,
        creditUtilization: 43.3,
        lastFourDigits: "1234",
        expiryDate: "12/28",
        interestRate: 18.99,
        minimumPayment: 150.00,
        paymentDueDate: "2025-09-15",
        recentTransactions: [
            CreditTransaction(id: "1", description: "Grocery Store", amount: 85.50, date: "2025-08-14", category: .groceries),
            CreditTransaction(id: "2", description: "Gas Station", amount: 45.00, date: "2025-08-13", category: .gas),
            CreditTransaction(id: "3", description: "Restaurant", amount: 65.75, date: "2025-08-12", category: .dining)
        ]
    )
}

extension LoanData {
    static let mock = [
        LoanData(
            id: "1",
            loanType: .auto,
            accountNumber: "AUTO-2024-001",
            outstandingBalance: 18500.00,
            interestRate: 4.25,
            monthlyPayment: 450.00,
            nextPaymentDate: "2025-09-01"
        ),
        LoanData(
            id: "2",
            loanType: .personal,
            accountNumber: "PERS-2024-001",
            outstandingBalance: 8500.00,
            interestRate: 7.50,
            monthlyPayment: 275.00,
            nextPaymentDate: "2025-09-15"
        )
    ]
}

extension LoyaltyData {
    static let mock = LoyaltyData(
        totalPoints: 2847,
        currentTier: .gold,
        pointsToNextTier: 153,
        tierProgress: 0.85,
        availableRewards: [
            LoyaltyReward(id: "1", name: "Free Coffee", description: "Redeem for a free coffee at any partner location", pointsRequired: 500),
            LoyaltyReward(id: "2", name: "Movie Tickets", description: "Get 2 movie tickets for any showing", pointsRequired: 1000),
            LoyaltyReward(id: "3", name: "Gift Card", description: "$25 gift card to your choice of retailer", pointsRequired: 2500)
        ],
        recentActivity: [
            LoyaltyActivity(id: "1", description: "Credit Card Purchase", points: 25, date: "2025-08-15"),
            LoyaltyActivity(id: "2", description: "Savings Account Bonus", points: 100, date: "2025-08-01"),
            LoyaltyActivity(id: "3", description: "Reward Redemption", points: -500, date: "2025-07-25")
        ]
    )
}

// MARK: - Shared UI Components
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
