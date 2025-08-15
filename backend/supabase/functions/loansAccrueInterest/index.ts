// Scheduled Function: Loans Accrue Interest
// Runs daily at 01:00
// For each ACTIVE loan in a month that has a due on the 28th, post monthly interest on the 1st
// DR loan CUSTOMER_INTEREST_CHARGED, CR BANK_INTEREST_EARNED

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

// Cron expression: 0 1 * * * (daily at 01:00)
// This function should be scheduled to run daily at 1:00 AM

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

    // Get today's date
    const today = new Date();
    const isFirstOfMonth = today.getDate() === 1;
    
    if (!isFirstOfMonth) {
      return new Response(JSON.stringify({ 
        message: "Interest accrual only runs on the 1st of each month",
        current_date: today.toISOString()
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      });
    }

    // Find all ACTIVE loans that have upcoming payments this month
    const { data: activeLoans, error: loansError } = await supabaseAdmin
      .from('lending_core.term_loans')
      .select(`
        loan_id,
        user_id,
        principal_amount_cents,
        monthly_interest_rate_bps,
        lending_core.repayment_schedule!inner(
          schedule_id,
          due_date,
          interest_due_cents,
          status
        )
      `)
      .eq('status', 'ACTIVE')
      .gte('lending_core.repayment_schedule.due_date', today.toISOString().split('T')[0])
      .lt('lending_core.repayment_schedule.due_date', new Date(today.getFullYear(), today.getMonth() + 1, 1).toISOString().split('T')[0])
      .eq('lending_core.repayment_schedule.status', 'PENDING');

    if (loansError) {
      console.error('Error fetching active loans:', loansError);
      return new Response(JSON.stringify({ 
        error: "Failed to fetch active loans", 
        details: loansError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    if (!activeLoans || activeLoans.length === 0) {
      return new Response(JSON.stringify({ 
        message: "No active loans with pending payments this month",
        processed_count: 0
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      });
    }

    let processedCount = 0;
    const errors: string[] = [];

    // Process each loan
    for (const loan of activeLoans) {
      try {
        // Get the loan's interest charged account
        const { data: interestChargedAccount, error: accountError } = await supabaseAdmin
          .from('ledger_accounts')
          .select('id')
          .eq('owner_type', 'LOAN')
          .eq('owner_id', loan.loan_id.toString())
          .eq('code', 'CUSTOMER_INTEREST_CHARGED')
          .single();

        if (accountError || !interestChargedAccount) {
          errors.push(`Loan ${loan.loan_id}: Interest charged account not found`);
          continue;
        }

        // Get the bank interest earned account
        const { data: bankInterestAccount, error: bankError } = await supabaseAdmin
          .from('ledger_accounts')
          .select('id')
          .eq('owner_type', 'BANK')
          .eq('owner_id', 'BANK:INTEREST')
          .eq('code', 'BANK_INTEREST_EARNED')
          .single();

        if (bankError || !bankInterestAccount) {
          errors.push(`Loan ${loan.loan_id}: Bank interest account not found`);
          continue;
        }

        // Calculate total interest for this month
        const monthlyInterest = loan.repayment_schedule.reduce((total, schedule) => {
          return total + schedule.interest_due_cents;
        }, 0);

        if (monthlyInterest <= 0) {
          continue; // Skip if no interest to accrue
        }

        // Create interest accrual posting
        const interestLines = [
          {
            account_id: interestChargedAccount.id,
            amount_cents: monthlyInterest,
            direction: 'DEBIT'
          },
          {
            account_id: bankInterestAccount.id,
            amount_cents: monthlyInterest,
            direction: 'CREDIT'
          }
        ];

        // Post the interest accrual transaction
        const { data: txnId, error: postingError } = await supabaseAdmin
          .rpc('post_balanced_transaction', {
            p_user: loan.user_id,
            p_idem: `interest_accrual_${loan.loan_id}_${today.getFullYear()}_${today.getMonth() + 1}`,
            p_lines: interestLines,
            p_meta: {
              loan_id: loan.loan_id,
              accrual_type: 'monthly_interest',
              month: today.getMonth() + 1,
              year: today.getFullYear(),
              interest_amount_cents: monthlyInterest
            }
          });

        if (postingError) {
          errors.push(`Loan ${loan.loan_id}: Failed to post interest accrual - ${postingError.message}`);
          continue;
        }

        processedCount++;
        console.log(`Processed interest accrual for loan ${loan.loan_id}: ${monthlyInterest} cents`);

      } catch (error) {
        errors.push(`Loan ${loan.loan_id}: ${error.message}`);
        continue;
      }
    }

    // Return summary
    const response = {
      message: "Interest accrual processing completed",
      processed_count: processedCount,
      total_loans: activeLoans.length,
      errors: errors.length > 0 ? errors : undefined,
      processed_at: today.toISOString()
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200
    });

  } catch (error) {
    console.error("Function error:", error);
    return new Response(JSON.stringify({ 
      error: "Internal server error",
      details: error.message
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500
    });
  }
});
