// jBank Backend Types and Interfaces
// Centralized type definitions for all services
// ============================================================================
// ENUMS
// ============================================================================
export var AccountType;
(function (AccountType) {
    AccountType["CHECKING"] = "checking";
    AccountType["SAVINGS"] = "savings";
    AccountType["LOAN"] = "loan";
    AccountType["CREDIT_CARD"] = "credit_card";
    AccountType["INVESTMENT"] = "investment";
})(AccountType || (AccountType = {}));
export var TransactionType;
(function (TransactionType) {
    TransactionType["DEPOSIT"] = "deposit";
    TransactionType["WITHDRAWAL"] = "withdrawal";
    TransactionType["TRANSFER"] = "transfer";
    TransactionType["PAYMENT"] = "payment";
    TransactionType["FEE"] = "fee";
    TransactionType["INTEREST"] = "interest";
    TransactionType["ADJUSTMENT"] = "adjustment";
})(TransactionType || (TransactionType = {}));
export var TransactionStatus;
(function (TransactionStatus) {
    TransactionStatus["PENDING"] = "pending";
    TransactionStatus["COMPLETED"] = "completed";
    TransactionStatus["FAILED"] = "failed";
    TransactionStatus["CANCELLED"] = "cancelled";
    TransactionStatus["REVERSED"] = "reversed";
})(TransactionStatus || (TransactionStatus = {}));
export var LoanStatus;
(function (LoanStatus) {
    LoanStatus["PENDING"] = "pending";
    LoanStatus["ACTIVE"] = "active";
    LoanStatus["PAID_OFF"] = "paid_off";
    LoanStatus["DEFAULTED"] = "defaulted";
    LoanStatus["RESTRUCTURED"] = "restructured";
})(LoanStatus || (LoanStatus = {}));
export var VerificationStatus;
(function (VerificationStatus) {
    VerificationStatus["UNVERIFIED"] = "unverified";
    VerificationStatus["PENDING"] = "pending";
    VerificationStatus["VERIFIED"] = "verified";
    VerificationStatus["REJECTED"] = "rejected";
})(VerificationStatus || (VerificationStatus = {}));
export var EntryType;
(function (EntryType) {
    EntryType["DEBIT"] = "debit";
    EntryType["CREDIT"] = "credit";
})(EntryType || (EntryType = {}));
