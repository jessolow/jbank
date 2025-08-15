// Core Ledger Internal Transfer Edge Function
// Builds 2-line postings (CR from, DR to) and calls ledgerPostings internally

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

interface TransferRequest {
  idempotency_key: string;
  from_account_id: number;
  to_account_id: number;
  amount_cents: number;
  meta?: Record<string, any>;
}

interface TransferResponse {
  txn_id: number;
  posted_at: string;
  from_account_id: number;
  to_account_id: number;
  amount_cents: number;
  currency: string;
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
    const body: TransferRequest = await req.json();
    
    if (!body.idempotency_key || !body.from_account_id || !body.to_account_id || !body.amount_cents) {
      return new Response(JSON.stringify({ 
        error: "Invalid request body. Required: idempotency_key, from_account_id, to_account_id, amount_cents" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Validate amount is positive
    if (body.amount_cents <= 0) {
      return new Response(JSON.stringify({ 
        error: "Amount must be positive" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Fetch both accounts to validate same currency
    const { data: accounts, error: accountsError } = await supabaseAdmin
      .from('ledger_accounts')
      .select('id, currency')
      .in('id', [body.from_account_id, body.to_account_id]);

    if (accountsError || !accounts || accounts.length !== 2) {
      return new Response(JSON.stringify({ 
        error: "Failed to fetch accounts or accounts not found" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Validate same currency for both accounts
    const fromAccount = accounts.find(a => a.id === body.from_account_id);
    const toAccount = accounts.find(a => a.id === body.to_account_id);
    
    if (!fromAccount || !toAccount || fromAccount.currency !== toAccount.currency) {
      return new Response(JSON.stringify({ 
        error: "Both accounts must have the same currency" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Build the 2-line posting (CR from, DR to)
    const lines = [
      {
        account_id: body.from_account_id,
        amount_cents: body.amount_cents,
        direction: 'CREDIT' as const
      },
      {
        account_id: body.to_account_id,
        amount_cents: body.amount_cents,
        direction: 'DEBIT' as const
      }
    ];

    // Call the post_balanced_transaction RPC function
    const { data: txnId, error: postingError } = await supabaseAdmin
      .rpc('post_balanced_transaction', {
        p_user: user.id,
        p_idem: body.idempotency_key,
        p_lines: lines,
        p_meta: {
          ...body.meta,
          transfer_type: 'internal',
          from_account_id: body.from_account_id,
          to_account_id: body.to_account_id
        }
      });

    if (postingError) {
      console.error('Posting error:', postingError);
      return new Response(JSON.stringify({ 
        error: "Failed to post transfer transaction", 
        details: postingError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Return the transfer response
    const response: TransferResponse = {
      txn_id: txnId,
      posted_at: new Date().toISOString(),
      from_account_id: body.from_account_id,
      to_account_id: body.to_account_id,
      amount_cents: body.amount_cents,
      currency: fromAccount.currency
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
