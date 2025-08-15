// jBank Backend Utilities
// Common utility functions used across all services

import { ValidationError, ValidationResult } from '../types/index.js';

// ============================================================================
// IDEMPOTENCY UTILITIES
// ============================================================================

/**
 * Generates a unique idempotency key
 */
export function generateIdempotencyKey(): string {
  const timestamp = Date.now().toString();
  const random = crypto.getRandomValues(new Uint8Array(16));
  const randomHex = Array.from(random).map(b => b.toString(16).padStart(2, '0')).join('');
  return `${timestamp}-${randomHex}`;
}

/**
 * Creates a hash from request data for idempotency checking
 */
export async function createRequestHash(data: any, userId: string): Promise<string> {
  const sortedData = JSON.stringify(data, Object.keys(data).sort());
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(sortedData + userId);
  const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// ============================================================================
// MONEY UTILITIES
// ============================================================================

/**
 * Converts dollars to cents
 */
export function dollarsToCents(dollars: number): number {
  return Math.round(dollars * 100);
}

/**
 * Converts cents to dollars
 */
export function centsToDollars(cents: number): number {
  return cents / 100;
}

/**
 * Formats money amount for display
 */
export function formatMoney(amountCents: number, currency: string = 'USD'): string {
  const amount = centsToDollars(amountCents);
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
  }).format(amount);
}

/**
 * Validates money amount (must be positive)
 */
export function validateMoneyAmount(amountCents: number): boolean {
  return amountCents > 0 && Number.isInteger(amountCents);
}

// ============================================================================
// VALIDATION UTILITIES
// ============================================================================

/**
 * Validates email format
 */
export function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * Validates phone number format (US)
 */
export function validatePhoneNumber(phone: string): boolean {
  const phoneRegex = /^\+?1?[-.\s]?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})$/;
  return phoneRegex.test(phone);
}

/**
 * Validates SSN format (US)
 */
export function validateSSN(ssn: string): boolean {
  const ssnRegex = /^\d{3}-?\d{2}-?\d{4}$/;
  return ssnRegex.test(ssn);
}

/**
 * Validates ZIP code format (US)
 */
export function validateZipCode(zip: string): boolean {
  const zipRegex = /^\d{5}(-\d{4})?$/;
  return zipRegex.test(zip);
}

/**
 * Validates state code (US)
 */
export function validateStateCode(state: string): boolean {
  const validStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ];
  return validStates.includes(state.toUpperCase());
}

/**
 * Creates a validation error
 */
export function createValidationError(field: string, message: string, code?: string): ValidationError {
  return {
    field,
    message,
    code: code || 'VALIDATION_ERROR'
  };
}

/**
 * Validates required fields
 */
export function validateRequiredFields(data: any, requiredFields: string[]): ValidationResult {
  const errors: ValidationError[] = [];
  
  for (const field of requiredFields) {
    if (data[field] === undefined || data[field] === null || data[field] === '') {
      errors.push(createValidationError(field, `${field} is required`));
    }
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
}

// ============================================================================
// ENCRYPTION UTILITIES
// ============================================================================

/**
 * Hashes sensitive data (like SSN) for storage
 */
export function hashSensitiveData(data: string, salt?: string): string {
  const dataToHash = salt ? data + salt : data;
  return createHash('sha256').update(dataToHash).digest('hex');
}

/**
 * Generates a random salt
 */
export function generateSalt(length: number = 32): string {
  const random = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(random).map(b => b.toString(16).padStart(2, '0')).join('');
}

// ============================================================================
// DATE UTILITIES
// ============================================================================

/**
 * Formats date for database storage
 */
export function formatDateForDB(date: Date | string): string {
  if (typeof date === 'string') {
    return new Date(date).toISOString();
  }
  return date.toISOString();
}

/**
 * Adds months to a date
 */
export function addMonths(date: Date, months: number): Date {
  const newDate = new Date(date);
  newDate.setMonth(newDate.getMonth() + months);
  return newDate;
}

/**
 * Calculates days between two dates
 */
export function daysBetween(date1: Date, date2: Date): number {
  const oneDay = 24 * 60 * 60 * 1000;
  return Math.round(Math.abs((date1.getTime() - date2.getTime()) / oneDay));
}

/**
 * Checks if a date is in the past
 */
export function isDateInPast(date: Date): boolean {
  return date < new Date();
}

// ============================================================================
// ACCOUNT NUMBER UTILITIES
// ============================================================================

/**
 * Generates a unique account number with prefix
 */
export function generateAccountNumber(prefix: string): string {
  const timestamp = Date.now().toString().slice(-8);
  const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `${prefix}${timestamp}${random}`;
}

/**
 * Validates account number format
 */
export function validateAccountNumber(accountNumber: string): boolean {
  // Account numbers should be 20 characters or less
  return accountNumber.length <= 20 && /^[A-Z0-9]+$/.test(accountNumber);
}

// ============================================================================
// ERROR HANDLING UTILITIES
// ============================================================================

/**
 * Creates a standardized error response
 */
export function createErrorResponse(message: string, statusCode: number = 400, details?: any) {
  return {
    success: false,
    error: message,
    details,
    statusCode
  };
}

/**
 * Creates a standardized success response
 */
export function createSuccessResponse<T>(data: T, message?: string) {
  return {
    success: true,
    data,
    message: message || 'Operation completed successfully'
  };
}

/**
 * Handles async errors in a standardized way
 */
export async function handleAsyncError<T>(
  operation: () => Promise<T>,
  errorMessage: string = 'An error occurred'
): Promise<{ success: boolean; data?: T; error?: string }> {
  try {
    const result = await operation();
    return { success: true, data: result };
  } catch (error) {
    console.error(`${errorMessage}:`, error);
    return { 
      success: false, 
      error: error instanceof Error ? error.message : errorMessage 
    };
  }
}

// ============================================================================
// LOGGING UTILITIES
// ============================================================================

/**
 * Logs operations with consistent format
 */
export function logOperation(operation: string, userId?: string, details?: any) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    operation,
    userId: userId || 'system',
    details
  };
  
  console.log(JSON.stringify(logEntry));
}

/**
 * Logs errors with consistent format
 */
export function logError(error: Error, context?: string, userId?: string) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level: 'ERROR',
    context: context || 'unknown',
    userId: userId || 'system',
    error: {
      message: error.message,
      stack: error.stack,
      name: error.name
    }
  };
  
  console.error(JSON.stringify(logEntry));
}

// ============================================================================
// TRANSACTION UTILITIES
// ============================================================================

/**
 * Generates a unique transaction reference
 */
export function generateTransactionReference(prefix: string = 'TXN'): string {
  const timestamp = Date.now().toString();
  const random = crypto.getRandomValues(new Uint8Array(8));
  const randomHex = Array.from(random).map(b => b.toString(16).padStart(2, '0')).join('').toUpperCase();
  return `${prefix}${timestamp}${randomHex}`;
}

/**
 * Validates transaction reference format
 */
export function validateTransactionReference(reference: string): boolean {
  return reference.length <= 50 && /^[A-Z0-9]+$/.test(reference);
}

// ============================================================================
// RISK SCORING UTILITIES
// ============================================================================

/**
 * Calculates basic risk score based on customer data
 */
export function calculateRiskScore(
  age: number,
  creditScore?: number,
  income?: number,
  employmentStatus?: string
): number {
  let score = 500; // Base score
  
  // Age factor
  if (age < 25) score += 100;
  else if (age > 65) score += 50;
  else if (age >= 35 && age <= 55) score -= 50;
  
  // Credit score factor
  if (creditScore) {
    if (creditScore >= 750) score -= 100;
    else if (creditScore >= 650) score -= 50;
    else if (creditScore < 550) score += 150;
  }
  
  // Income factor
  if (income) {
    if (income >= 100000) score -= 75;
    else if (income < 30000) score += 100;
  }
  
  // Employment factor
  if (employmentStatus === 'employed') score -= 25;
  else if (employmentStatus === 'unemployed') score += 100;
  
  // Ensure score is within bounds
  return Math.max(0, Math.min(1000, score));
}
