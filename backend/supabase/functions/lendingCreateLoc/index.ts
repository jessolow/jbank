// Lending Core Create Line of Credit Edge Function
// Creates LoC accounts with unique account numbers

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

interface CreateLocRequest {
  currency: string;
  credit_limit_cents: number;
}

interface CreateLocResponse {
  loc_account_id: number;
  account_number: string;
  credit_limit_cents: number;
  currency: string;
}

// Generate unique account number: LOC-{YYYY}{random}
function generateAccountNumber(): string {
  const year = new Date().getFullYear();
  const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `LOC-${year}${random}`;
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
    const body: CreateLocRequest = await req.json();
    
    if (!body.currency || !body.credit_limit_cents) {
      return new Response(JSON.stringify({ 
        error: "Currency and credit_limit_cents are required" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Validate currency format
    if (typeof body.currency !== 'string' || body.currency.length !== 3) {
      return new Response(JSON.stringify({ 
        error: "Currency must be a 3-character code (e.g., USD, EUR)" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Validate credit limit
    if (typeof body.credit_limit_cents !== 'number' || body.credit_limit_cents <= 0) {
      return new Response(JSON.stringify({ 
        error: "Credit limit must be a positive number" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Generate unique account number
    let accountNumber: string;
    let attempts = 0;
    const maxAttempts = 10;
    
    do {
      accountNumber = generateAccountNumber();
      attempts++;
      
      // Check if account number already exists
      const { data: existing, error: checkError } = await supabaseAdmin
        .from('lending_core.loc_accounts')
        .select('account_number')
        .eq('account_number', accountNumber)
        .single();
      
      if (checkError && checkError.code !== 'PGRST116') { // PGRST116 = no rows returned
        console.error('Error checking account number uniqueness:', checkError);
        break;
      }
      
      if (!existing) {
        break; // Account number is unique
      }
      
    } while (attempts < maxAttempts);
    
    if (attempts >= maxAttempts) {
      return new Response(JSON.stringify({ 
        error: "Failed to generate unique account number after multiple attempts" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Insert the LoC account
    const { data: locAccount, error: insertError } = await supabaseAdmin
      .from('lending_core.loc_accounts')
      .insert({
        user_id: user.id,
        account_number: accountNumber,
        currency: body.currency.toUpperCase(),
        credit_limit_cents: body.credit_limit_cents
      })
      .select('loc_account_id, account_number, credit_limit_cents, currency')
      .single();

    if (insertError) {
      console.error('LoC account creation error:', insertError);
      return new Response(JSON.stringify({ 
        error: "Failed to create LoC account", 
        details: insertError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Return the LoC account details as specified
    const response: CreateLocResponse = {
      loc_account_id: locAccount.loc_account_id,
      account_number: locAccount.account_number,
      credit_limit_cents: locAccount.credit_limit_cents,
      currency: locAccount.currency
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
