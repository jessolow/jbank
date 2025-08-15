// jBank Backend Types and Interfaces
// Centralized type definitions for all services

// ============================================================================
// ENUMS
// ============================================================================

export enum AccountType {
  CHECKING = 'checking',
  SAVINGS = 'savings',
  LOAN = 'loan',
  CREDIT_CARD = 'credit_card',
  INVESTMENT = 'investment'
}

export enum TransactionType {
  DEPOSIT = 'deposit',
  WITHDRAWAL = 'withdrawal',
  TRANSFER = 'transfer',
  PAYMENT = 'payment',
  FEE = 'fee',
  INTEREST = 'interest',
  ADJUSTMENT = 'adjustment'
}

export enum TransactionStatus {
  PENDING = 'pending',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled',
  REVERSED = 'reversed'
}

export enum LoanStatus {
  PENDING = 'pending',
  ACTIVE = 'active',
  PAID_OFF = 'paid_off',
  DEFAULTED = 'defaulted',
  RESTRUCTURED = 'restructured'
}

export enum VerificationStatus {
  UNVERIFIED = 'unverified',
  PENDING = 'pending',
  VERIFIED = 'verified',
  REJECTED = 'rejected'
}

export enum EntryType {
  DEBIT = 'debit',
  CREDIT = 'credit'
}

// ============================================================================
// BASE INTERFACES
// ============================================================================

export interface BaseEntity {
  id: string;
  created_at: string;
  updated_at?: string;
}

export interface MoneyAmount {
  amount_cents: number;
  currency?: string; // Defaults to USD
}

export interface Address {
  address_line_1: string;
  address_line_2?: string;
  city: string;
  state: string;
  zip_code: string;
  country?: string; // Defaults to US
}

// ============================================================================
// CUSTOMER MASTER SERVICE
// ============================================================================

export interface CustomerProfile extends BaseEntity {
  auth_user_id: string;
  customer_number: string;
  first_name: string;
  last_name: string;
  email: string;
  phone_number?: string;
  date_of_birth?: string;
  ssn_hash?: string;
  address?: Address;
  verification_status: VerificationStatus;
  kyc_completed_at?: string;
  risk_score: number;
  is_active: boolean;
}

export interface CreateCustomerRequest {
  auth_user_id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone_number?: string;
  date_of_birth?: string;
  ssn?: string; // Will be hashed
  address?: Address;
}

export interface UpdateCustomerRequest {
  first_name?: string;
  last_name?: string;
  phone_number?: string;
  address?: Address;
  verification_status?: VerificationStatus;
}

// ============================================================================
// CORE LEDGER SERVICE
// ============================================================================

export interface LedgerEntry extends BaseEntity {
  account_id: string;
  transaction_id: string;
  entry_type: EntryType;
  amount_cents: number;
  balance_before_cents: number;
  balance_after_cents: number;
  reference_number?: string;
  description?: string;
}

export interface CreateLedgerEntryRequest {
  account_id: string;
  transaction_id: string;
  entry_type: EntryType;
  amount_cents: number;
  balance_before_cents: number;
  balance_after_cents: number;
  reference_number?: string;
  description?: string;
}

// ============================================================================
// TRANSACTION HISTORY SERVICE
// ============================================================================

export interface Transaction extends BaseEntity {
  transaction_reference: string;
  from_account_id?: string;
  to_account_id?: string;
  transaction_type: TransactionType;
  amount_cents: number;
  fee_cents: number;
  total_amount_cents: number;
  status: TransactionStatus;
  description?: string;
  metadata?: Record<string, any>;
  processed_at?: string;
}

export interface CreateTransactionRequest {
  from_account_id?: string;
  to_account_id?: string;
  transaction_type: TransactionType;
  amount_cents: number;
  fee_cents?: number;
  description?: string;
  metadata?: Record<string, any>;
}

export interface TransactionFilter {
  account_id?: string;
  transaction_type?: TransactionType;
  status?: TransactionStatus;
  from_date?: string;
  to_date?: string;
  limit?: number;
  offset?: number;
}

// ============================================================================
// DEPOSIT CORE SERVICE
// ============================================================================

export interface DepositAccount extends BaseEntity {
  customer_id: string;
  account_number: string;
  account_type: AccountType;
  balance_cents: number;
  available_balance_cents: number;
  hold_amount_cents: number;
  interest_rate: number;
  minimum_balance_cents: number;
  monthly_fee_cents: number;
  is_active: boolean;
  opened_at: string;
  closed_at?: string;
}

export interface CreateDepositAccountRequest {
  customer_id: string;
  account_type: AccountType;
  initial_deposit_cents?: number;
  interest_rate?: number;
  minimum_balance_cents?: number;
  monthly_fee_cents?: number;
}

export interface DepositRequest {
  account_id: string;
  amount_cents: number;
  description?: string;
  reference?: string;
}

export interface WithdrawalRequest {
  account_id: string;
  amount_cents: number;
  description?: string;
  reference?: string;
}

export interface TransferRequest {
  from_account_id: string;
  to_account_id: string;
  amount_cents: number;
  description?: string;
  reference?: string;
}

// ============================================================================
// LENDING CORE SERVICE
// ============================================================================

export interface LoanAccount extends BaseEntity {
  customer_id: string;
  loan_number: string;
  loan_type: string;
  principal_amount_cents: number;
  outstanding_balance_cents: number;
  interest_rate: number;
  term_months: number;
  monthly_payment_cents: number;
  next_payment_date: string;
  status: LoanStatus;
  disbursed_at?: string;
  maturity_date?: string;
}

export interface CreateLoanRequest {
  customer_id: string;
  loan_type: string;
  principal_amount_cents: number;
  interest_rate: number;
  term_months: number;
  monthly_payment_cents: number;
  next_payment_date: string;
}

export interface LoanPayment extends BaseEntity {
  loan_id: string;
  payment_reference: string;
  payment_amount_cents: number;
  principal_paid_cents: number;
  interest_paid_cents: number;
  late_fee_cents: number;
  payment_date: string;
  due_date: string;
  is_late: boolean;
}

export interface CreateLoanPaymentRequest {
  loan_id: string;
  payment_amount_cents: number;
  payment_date: string;
  due_date: string;
}

// ============================================================================
// API RESPONSE INTERFACES
// ============================================================================

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
  errors?: Record<string, string[]>;
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number;
    limit: number;
    total: number;
    total_pages: number;
  };
}

// ============================================================================
// VALIDATION INTERFACES
// ============================================================================

export interface ValidationError {
  field: string;
  message: string;
  code?: string;
}

export interface ValidationResult {
  isValid: boolean;
  errors: ValidationError[];
}

// ============================================================================
// UTILITY TYPES
// ============================================================================

export type IdempotencyKey = string;
export type TransactionReference = string;
export type AccountNumber = string;
export type CustomerNumber = string;
export type LoanNumber = string;

// ============================================================================
// CONFIGURATION INTERFACES
// ============================================================================

export interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  username: string;
  password: string;
  ssl?: boolean;
}

export interface SupabaseConfig {
  url: string;
  service_role_key: string;
  anon_key: string;
}

export interface AppConfig {
  environment: 'development' | 'staging' | 'production';
  port: number;
  database: DatabaseConfig;
  supabase: SupabaseConfig;
  jwt_secret: string;
  encryption_key: string;
}
