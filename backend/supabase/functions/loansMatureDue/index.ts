// Scheduled Function: Loans Mature Due
// Runs daily at 00:10
// On the 28th, reclassify that period's amounts:
// Move from CUSTOMER_PRINCIPAL_CHARGED → CUSTOMER_PRINCIPAL_DUE
// Move from CUSTOMER_INTEREST_CHARGED → CUSTOMER_INTEREST_DUE
// Use ledger postings with equal and opposite entries; update repayment_schedule.status to DUE

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

// Cron expression: 10 0 * * * (daily at 00:10)
// This function should be scheduled to run daily at 12:10 AM

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
    const is28th = today.getDate() === 28;
    
    if (!is28th) {
      return new Response(JSON.stringify({ 
        message: "Due date processing only runs on the 28th of each month",
        current_date: today.toISOString()
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      });
    }

    // Find all ACTIVE loans with PENDING schedule items due today
    const { data: dueLoans, error: loansError } = await supabaseAdmin
      .from('lending_core.term_loans')
      .select(`
        loan_id,
        user_id,
        lending_core.repayment_schedule!inner(
          schedule_id,
          due_date,
          principal_due_cents,
          interest_due_cents,
          status
        )
      `)
      .eq('status', 'ACTIVE')
      .eq('lending_core.repayment_schedule.due_date', today.toISOString().split('T')[0])
      .eq('lending_core.repayment_schedule.status', 'PENDING');

    if (loansError) {
      console.error('Error fetching due loans:', loansError);
      return new Response(JSON.stringify({ 
        error: "Failed to fetch due loans", 
        details: loansError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    if (!dueLoans || dueLoans.length === 0) {
      return new Response(JSON.stringify({ 
        message: "No loans with payments due today",
        processed_count: 0
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      });
    }

    let processedCount = 0;
    const errors: string[] = [];

    // Process each loan
    for (const loan of dueLoans) {
      try {
        // Get the loan's ledger accounts
        const { data: accounts, error: accountsError } = await supabaseAdmin
          .from('ledger_accounts')
          .select('id, code')
          .eq('owner_type', 'LOAN')
          .eq('owner_id', loan.loan_id.toString())
          .in('code', [
            'CUSTOMER_PRINCIPAL_CHARGED',
            'CUSTOMER_PRINCIPAL_DUE',
            'CUSTOMER_INTEREST_CHARGED',
            'CUSTOMER_INTEREST_DUE'
          ]);

        if (accountsError || !accounts || accounts.length !== 4) {
          errors.push(`Loan ${loan.loan_id}: Required ledger accounts not found`);
          continue;
        }

        const accountMap = accounts.reduce((map, acc) => {
          map[acc.code] = acc.id;
          return map;
        }, {} as Record<string, number>);

        // Calculate total amounts due for this period
        const totalPrincipal = loan.repayment_schedule.reduce((total, schedule) => {
          return total + schedule.principal_due_cents;
        }, 0);

        const totalInterest = loan.repayment_schedule.reduce((total, schedule) => {
          return total + schedule.interest_due_cents;
        }, 0);

        // Create reclassification postings for principal
        if (totalPrincipal > 0) {
          const principalLines = [
            {
              account_id: accountMap['CUSTOMER_PRINCIPAL_CHARGED'],
              amount_cents: totalPrincipal,
              direction: 'CREDIT' // Reduce charged amount
            },
            {
              account_id: accountMap['CUSTOMER_PRINCIPAL_DUE'],
              amount_cents: totalPrincipal,
              direction: 'DEBIT' // Increase due amount
            }
          ];

          // Post the principal reclassification
          const { error: principalError } = await supabaseAdmin
            .rpc('post_balanced_transaction', {
              p_user: loan.user_id,
              p_idem: `principal_reclass_${loan.loan_id}_${today.getFullYear()}_${today.getMonth() + 1}`,
              p_lines: principalLines,
              p_meta: {
                loan_id: loan.loan_id,
                reclass_type: 'principal_charged_to_due',
                month: today.getMonth() + 1,
                year: today.getFullYear(),
                amount_cents: totalPrincipal
              }
            });

          if (principalError) {
            errors.push(`Loan ${loan.loan_id}: Failed to reclassify principal - ${principalError.message}`);
            continue;
          }
        }

        // Create reclassification postings for interest
        if (totalInterest > 0) {
          const interestLines = [
            {
              account_id: accountMap['CUSTOMER_INTEREST_CHARGED'],
              amount_cents: totalInterest,
              direction: 'CREDIT' // Reduce charged amount
            },
            {
              account_id: accountMap['CUSTOMER_INTEREST_DUE'],
              amount_cents: totalInterest,
              direction: 'DEBIT' // Increase due amount
            }
          ];

          // Post the interest reclassification
          const { error: interestError } = await supabaseAdmin
            .rpc('post_balanced_transaction', {
              p_user: loan.user_id,
              p_idem: `interest_reclass_${loan.loan_id}_${today.getFullYear()}_${today.getMonth() + 1}`,
              p_lines: interestLines,
              p_meta: {
                loan_id: loan.loan_id,
                reclass_type: 'interest_charged_to_due',
                month: today.getMonth() + 1,
                year: today.getFullYear(),
                amount_cents: totalInterest
              }
            });

          if (interestError) {
            errors.push(`Loan ${loan.loan_id}: Failed to reclassify interest - ${interestError.message}`);
            continue;
          }
        }

        // Update all schedule rows for today to DUE status
        const { error: updateError } = await supabaseAdmin
          .from('lending_core.repayment_schedule')
          .update({ status: 'DUE' })
          .eq('loan_id', loan.loan_id)
          .eq('due_date', today.toISOString().split('T')[0])
          .eq('status', 'PENDING');

        if (updateError) {
          errors.push(`Loan ${loan.loan_id}: Failed to update schedule status - ${updateError.message}`);
          continue;
        }

        processedCount++;
        console.log(`Processed due date for loan ${loan.loan_id}: Principal ${totalPrincipal} cents, Interest ${totalInterest} cents`);

      } catch (error) {
        errors.push(`Loan ${loan.loan_id}: ${error.message}`);
        continue;
      }
    }

    // Return summary
    const response = {
      message: "Due date processing completed",
      processed_count: processedCount,
      total_loans: dueLoans.length,
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
