// Deposit Core Create Account Edge Function
// Creates deposit accounts and auto-creates related ledger accounts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

interface CreateDepositRequest {
  currency: string;
}

interface CreateDepositResponse {
  deposit_account_id: number;
  ledger_account_id: number;
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
    const body: CreateDepositRequest = await req.json();
    
    if (!body.currency) {
      return new Response(JSON.stringify({ 
        error: "Currency is required" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Validate currency format (basic validation)
    if (typeof body.currency !== 'string' || body.currency.length !== 3) {
      return new Response(JSON.stringify({ 
        error: "Currency must be a 3-character code (e.g., USD, EUR)" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Insert a deposit account row for the authenticated user
    const { data: depositAccount, error: depositError } = await supabaseAdmin
      .from('deposit_core.deposit_accounts')
      .insert({
        user_id: user.id,
        currency: body.currency.toUpperCase(),
        status: 'ACTIVE'
      })
      .select('id')
      .single();

    if (depositError) {
      console.error('Deposit account creation error:', depositError);
      return new Response(JSON.stringify({ 
        error: "Failed to create deposit account", 
        details: depositError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // The trigger should have created the ledger account automatically
    // Let's fetch it to confirm and get the ID
    const { data: ledgerAccount, error: ledgerError } = await supabaseAdmin
      .from('ledger_accounts')
      .select('id')
      .eq('owner_type', 'CUSTOMER')
      .eq('owner_id', `${user.id}:${depositAccount.id}`)
      .eq('code', 'CUSTOMER_DEPOSIT_ACCOUNT')
      .eq('currency', body.currency.toUpperCase())
      .single();

    if (ledgerError || !ledgerAccount) {
      console.error('Ledger account lookup error:', ledgerError);
      return new Response(JSON.stringify({ 
        error: "Deposit account created but ledger account not found", 
        details: ledgerError?.message || 'Ledger account not created by trigger'
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Return both IDs as specified
    const response: CreateDepositResponse = {
      deposit_account_id: depositAccount.id,
      ledger_account_id: ledgerAccount.id
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
