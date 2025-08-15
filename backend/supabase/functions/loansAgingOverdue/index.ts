// Scheduled Function: Loans Aging Overdue
// Runs daily at 00:30
// For overdue unpaid amounts, reclassify:
// Move amounts from CUSTOMER_PRINCIPAL_DUE → CUSTOMER_PRINCIPAL_OVERDUE
// Move amounts from CUSTOMER_INTEREST_DUE → CUSTOMER_INTEREST_OVERDUE
// Compute unpaid portions; mark schedule rows OVERDUE

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

// Cron expression: 30 0 * * * (daily at 00:30)
// This function should be scheduled to run daily at 12:30 AM

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
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    // Find all ACTIVE loans with DUE schedule items that are overdue (due date < today)
    const { data: overdueLoans, error: loansError } = await supabaseAdmin
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
      .lt('lending_core.repayment_schedule.due_date', today.toISOString().split('T')[0])
      .eq('lending_core.repayment_schedule.status', 'DUE');

    if (loansError) {
      console.error('Error fetching overdue loans:', loansError);
      return new Response(JSON.stringify({ 
        error: "Failed to fetch overdue loans", 
        details: loansError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    if (!overdueLoans || overdueLoans.length === 0) {
      return new Response(JSON.stringify({ 
        message: "No loans with overdue payments",
        processed_count: 0
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      });
    }

    let processedCount = 0;
    const errors: string[] = [];

    // Process each loan
    for (const loan of overdueLoans) {
      try {
        // Get the loan's ledger accounts
        const { data: accounts, error: accountsError } = await supabaseAdmin
          .from('ledger_accounts')
          .select('id, code')
          .eq('owner_type', 'LOAN')
          .eq('owner_id', loan.loan_id.toString())
          .in('code', [
            'CUSTOMER_PRINCIPAL_DUE',
            'CUSTOMER_PRINCIPAL_OVERDUE',
            'CUSTOMER_INTEREST_DUE',
            'CUSTOMER_INTEREST_OVERDUE'
          ]);

        if (accountsError || !accounts || accounts.length !== 4) {
          errors.push(`Loan ${loan.loan_id}: Required ledger accounts not found`);
          continue;
        }

        const accountMap = accounts.reduce((map, acc) => {
          map[acc.code] = acc.id;
          return map;
        }, {} as Record<string, number>);

        // Calculate total overdue amounts for this loan
        const totalOverduePrincipal = loan.repayment_schedule.reduce((total, schedule) => {
          return total + schedule.principal_due_cents;
        }, 0);

        const totalOverdueInterest = loan.repayment_schedule.reduce((total, schedule) => {
          return total + schedule.interest_due_cents;
        }, 0);

        // Create reclassification postings for overdue principal
        if (totalOverduePrincipal > 0) {
          const principalLines = [
            {
              account_id: accountMap['CUSTOMER_PRINCIPAL_DUE'],
              amount_cents: totalOverduePrincipal,
              direction: 'CREDIT' // Reduce due amount
            },
            {
              account_id: accountMap['CUSTOMER_PRINCIPAL_OVERDUE'],
              amount_cents: totalOverduePrincipal,
              direction: 'DEBIT' // Increase overdue amount
            }
          ];

          // Post the principal overdue reclassification
          const { error: principalError } = await supabaseAdmin
            .rpc('post_balanced_transaction', {
              p_user: loan.user_id,
              p_idem: `principal_overdue_${loan.loan_id}_${today.getTime()}`,
              p_lines: principalLines,
              p_meta: {
                loan_id: loan.loan_id,
                reclass_type: 'principal_due_to_overdue',
                overdue_date: today.toISOString().split('T')[0],
                amount_cents: totalOverduePrincipal
              }
            });

          if (principalError) {
            errors.push(`Loan ${loan.loan_id}: Failed to reclassify overdue principal - ${principalError.message}`);
            continue;
          }
        }

        // Create reclassification postings for overdue interest
        if (totalOverdueInterest > 0) {
          const interestLines = [
            {
              account_id: accountMap['CUSTOMER_INTEREST_DUE'],
              amount_cents: totalOverdueInterest,
              direction: 'CREDIT' // Reduce due amount
            },
            {
              account_id: accountMap['CUSTOMER_INTEREST_OVERDUE'],
              amount_cents: totalOverdueInterest,
              direction: 'DEBIT' // Increase overdue amount
            }
          ];

          // Post the interest overdue reclassification
          const { error: interestError } = await supabaseAdmin
            .rpc('post_balanced_transaction', {
              p_user: loan.user_id,
              p_idem: `interest_overdue_${loan.loan_id}_${today.getTime()}`,
              p_lines: interestLines,
              p_meta: {
                loan_id: loan.loan_id,
                reclass_type: 'interest_due_to_overdue',
                overdue_date: today.toISOString().split('T')[0],
                amount_cents: totalOverdueInterest
              }
            });

          if (interestError) {
            errors.push(`Loan ${loan.loan_id}: Failed to reclassify overdue interest - ${interestError.message}`);
            continue;
          }
        }

        // Update all overdue schedule rows to OVERDUE status
        const { error: updateError } = await supabaseAdmin
          .from('lending_core.repayment_schedule')
          .update({ status: 'OVERDUE' })
          .eq('loan_id', loan.loan_id)
          .lt('due_date', today.toISOString().split('T')[0])
          .eq('status', 'DUE');

        if (updateError) {
          errors.push(`Loan ${loan.loan_id}: Failed to update schedule status - ${updateError.message}`);
          continue;
        }

        processedCount++;
        console.log(`Processed overdue aging for loan ${loan.loan_id}: Principal ${totalOverduePrincipal} cents, Interest ${totalOverdueInterest} cents`);

      } catch (error) {
        errors.push(`Loan ${loan.loan_id}: ${error.message}`);
        continue;
      }
    }

    // Return summary
    const response = {
      message: "Overdue aging processing completed",
      processed_count: processedCount,
      total_loans: overdueLoans.length,
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
