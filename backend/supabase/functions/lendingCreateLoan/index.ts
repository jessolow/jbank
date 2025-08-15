// Lending Core Create Loan Edge Function
// Creates term loans with repayment schedules and disbursal postings

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

interface CreateLoanRequest {
  loc_account_number: string;
  loan_type: 'TERM';
  principal_amount_cents: number;
  monthly_interest_rate_bps: number;
  tenure_months: number;
  deposit_account_id: number;
  idempotency_key: string;
}

interface CreateLoanResponse {
  loan_id: number;
  loan_account_number: string;
  schedule_count: number;
  disbursal_txn_id: number;
}

// Generate unique loan account number: LN-{YYYY}{random}
function generateLoanAccountNumber(): string {
  const year = new Date().getFullYear();
  const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `LN-${year}${random}`;
}

// Calculate monthly payment using amortization formula
function calculateMonthlyPayment(principal: number, monthlyRate: number, months: number): number {
  if (monthlyRate === 0) return principal / months;
  
  const rate = monthlyRate / 10000; // Convert basis points to decimal
  const payment = principal * (rate * Math.pow(1 + rate, months)) / (Math.pow(1 + rate, months) - 1);
  return Math.round(payment);
}

// Generate repayment schedule with reducing balance
function generateRepaymentSchedule(
  principal: number, 
  monthlyRate: number, 
  months: number, 
  startDate: Date
): Array<{due_date: string, principal_due_cents: number, interest_due_cents: number}> {
  const schedule = [];
  let remainingPrincipal = principal;
  const rate = monthlyRate / 10000; // Convert basis points to decimal
  
  for (let i = 1; i <= months; i++) {
    // Calculate due date (28th of each month, starting next month)
    const dueDate = new Date(startDate);
    dueDate.setMonth(dueDate.getMonth() + i);
    dueDate.setDate(28);
    
    // Calculate interest for this period
    const interestDue = Math.round(remainingPrincipal * rate);
    
    // Calculate principal due (monthly payment minus interest)
    const monthlyPayment = calculateMonthlyPayment(principal, monthlyRate, months);
    const principalDue = Math.min(monthlyPayment - interestDue, remainingPrincipal);
    
    schedule.push({
      due_date: dueDate.toISOString().split('T')[0],
      principal_due_cents: principalDue,
      interest_due_cents: interestDue
    });
    
    remainingPrincipal -= principalDue;
  }
  
  return schedule;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Check if it's a POST request
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ 
        error: "Method not allowed. Only POST is supported." 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 405
      });
    }

    // Get the JWT token from the Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ 
        error: "Missing authorization header" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401
      });
    }

    // Extract the token from "Bearer <token>"
    const token = authHeader.replace('Bearer ', '');
    if (!token) {
      return new Response(JSON.stringify({ 
        error: "Invalid authorization header format" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401
      });
    }

    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(JSON.stringify({ 
        error: "Missing Supabase configuration" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }
    
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

    // Verify the JWT token and extract user info
    const { data: { user }, error: verifyError } = await supabaseAdmin.auth.getUser(token);
    
    if (verifyError || !user) {
      return new Response(JSON.stringify({ 
        error: "Invalid or expired token" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401
      });
    }

    // Parse request body
    const body: CreateLoanRequest = await req.json();
    
    if (!body.loc_account_number || !body.principal_amount_cents || 
        !body.monthly_interest_rate_bps || !body.tenure_months || 
        !body.deposit_account_id || !body.idempotency_key) {
      return new Response(JSON.stringify({ 
        error: "All fields are required: loc_account_number, principal_amount_cents, monthly_interest_rate_bps, tenure_months, deposit_account_id, idempotency_key" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Validate loan type
    if (body.loan_type !== 'TERM') {
      return new Response(JSON.stringify({ 
        error: "Only TERM loans are supported" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Validate amounts
    if (body.principal_amount_cents <= 0 || body.monthly_interest_rate_bps < 0 || body.tenure_months <= 0) {
      return new Response(JSON.stringify({ 
        error: "Principal amount, interest rate, and tenure must be positive" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Step 1: Resolve loc_account_number to LoC and check available credit
    const { data: locAccount, error: locError } = await supabaseAdmin
      .from('lending_core.loc_accounts')
      .select('loc_account_id, user_id, currency, credit_limit_cents')
      .eq('account_number', body.loc_account_number)
      .eq('user_id', user.id)
      .single();

    if (locError || !locAccount) {
      return new Response(JSON.stringify({ 
        error: "Line of Credit not found or access denied" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404
      });
    }

    // Check available credit from loc_exposure view
    const { data: exposure, error: exposureError } = await supabaseAdmin
      .from('lending_core.loc_exposure')
      .select('available_credit_cents')
      .eq('loc_account_id', locAccount.loc_account_id)
      .single();

    if (exposureError || !exposure) {
      return new Response(JSON.stringify({ 
        error: "Failed to check available credit" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Reject if principal > available credit
    if (body.principal_amount_cents > exposure.available_credit_cents) {
      return new Response(JSON.stringify({ 
        error: `Principal amount (${body.principal_amount_cents} cents) exceeds available credit (${exposure.available_credit_cents} cents)` 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Step 2: Create term_loans row
    const startDate = new Date();
    const maturityDate = new Date(startDate);
    maturityDate.setMonth(maturityDate.getMonth() + body.tenure_months);

    let loanAccountNumber: string;
    let attempts = 0;
    const maxAttempts = 10;
    
    do {
      loanAccountNumber = generateLoanAccountNumber();
      attempts++;
      
      // Check if account number already exists
      const { data: existing, error: checkError } = await supabaseAdmin
        .from('lending_core.term_loans')
        .select('loan_account_number')
        .eq('loan_account_number', loanAccountNumber)
        .single();
      
      if (checkError && checkError.code !== 'PGRST116') { // PGRST116 = no rows returned
        console.error('Error checking loan account number uniqueness:', checkError);
        break;
      }
      
      if (!existing) {
        break; // Account number is unique
      }
      
    } while (attempts < maxAttempts);
    
    if (attempts >= maxAttempts) {
      return new Response(JSON.stringify({ 
        error: "Failed to generate unique loan account number after multiple attempts" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    const { data: termLoan, error: loanError } = await supabaseAdmin
      .from('lending_core.term_loans')
      .insert({
        loc_account_id: locAccount.loc_account_id,
        user_id: user.id,
        loan_account_number: loanAccountNumber,
        principal_amount_cents: body.principal_amount_cents,
        monthly_interest_rate_bps: body.monthly_interest_rate_bps,
        tenure_months: body.tenure_months,
        start_date: startDate.toISOString().split('T')[0],
        maturity_date: maturityDate.toISOString().split('T')[0],
        status: 'ACTIVE'
      })
      .select('loan_id')
      .single();

    if (loanError) {
      console.error('Term loan creation error:', loanError);
      return new Response(JSON.stringify({ 
        error: "Failed to create term loan", 
        details: loanError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Step 3: Generate the repayment schedule
    const schedule = generateRepaymentSchedule(
      body.principal_amount_cents,
      body.monthly_interest_rate_bps,
      body.tenure_months,
      startDate
    );

    // Insert all schedule rows
    const { error: scheduleError } = await supabaseAdmin
      .from('lending_core.repayment_schedule')
      .insert(schedule.map(item => ({
        loan_id: termLoan.loan_id,
        due_date: item.due_date,
        principal_due_cents: item.principal_due_cents,
        interest_due_cents: item.interest_due_cents,
        status: 'PENDING'
      })));

    if (scheduleError) {
      console.error('Schedule creation error:', scheduleError);
      return new Response(JSON.stringify({ 
        error: "Failed to create repayment schedule", 
        details: scheduleError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Step 4: Disbursal posting via ledgerPostings
    // Get the loan's principal charged account ID
    const { data: principalChargedAccount, error: accountError } = await supabaseAdmin
      .from('ledger_accounts')
      .select('id')
      .eq('owner_type', 'LOAN')
      .eq('owner_id', termLoan.loan_id.toString())
      .eq('code', 'CUSTOMER_PRINCIPAL_CHARGED')
      .single();

    if (accountError || !principalChargedAccount) {
      return new Response(JSON.stringify({ 
        error: "Failed to find loan principal charged account" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Create disbursal posting: DR deposit account, CR loan principal charged
    const disbursalLines = [
      {
        account_id: body.deposit_account_id,
        amount_cents: body.principal_amount_cents,
        direction: 'DEBIT'
      },
      {
        account_id: principalChargedAccount.id,
        amount_cents: body.principal_amount_cents,
        direction: 'CREDIT'
      }
    ];

    // Call post_balanced_transaction for disbursal
    const { data: disbursalTxnId, error: disbursalError } = await supabaseAdmin
      .rpc('post_balanced_transaction', {
        p_user: user.id,
        p_idem: `${body.idempotency_key}_disbursal`,
        p_lines: disbursalLines,
        p_meta: {
          loan_id: termLoan.loan_id,
          disbursal_type: 'loan_disbursal',
          principal_amount_cents: body.principal_amount_cents
        }
      });

    if (disbursalError) {
      console.error('Disbursal posting error:', disbursalError);
      return new Response(JSON.stringify({ 
        error: "Failed to post disbursal transaction", 
        details: disbursalError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Return success response as specified
    const response: CreateLoanResponse = {
      loan_id: termLoan.loan_id,
      loan_account_number: loanAccountNumber,
      schedule_count: schedule.length,
      disbursal_txn_id: disbursalTxnId
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200
    });

  } catch (error) {
    console.error("Function error:", error);
    return new Response(JSON.stringify({ 
      error: "Internal server error" 
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500
    });
  }
});
