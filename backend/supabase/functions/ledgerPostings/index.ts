// Core Ledger Postings Edge Function
// Accepts JSON with transaction lines and posts balanced transactions

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

interface LedgerLine {
  account_id: number;
  amount_cents: number;
  direction: 'DEBIT' | 'CREDIT';
}

interface PostingRequest {
  idempotency_key: string;
  lines: LedgerLine[];
  meta?: Record<string, any>;
}

interface PostingResponse {
  txn_id: number;
  posted_at: string;
  totals: {
    debits: number;
    credits: number;
    net: number;
  };
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
    const body: PostingRequest = await req.json();
    
    if (!body.idempotency_key || !body.lines || !Array.isArray(body.lines)) {
      return new Response(JSON.stringify({ 
        error: "Invalid request body. Required: idempotency_key, lines array" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Convert direction to signed amount_cents (+debit, -credit)
    const convertedLines = body.lines.map(line => ({
      account_id: line.account_id,
      amount_cents: line.direction === 'DEBIT' ? line.amount_cents : -line.amount_cents
    }));

    // Calculate totals for response
    const totals = {
      debits: body.lines.filter(l => l.direction === 'DEBIT').reduce((sum, l) => sum + l.amount_cents, 0),
      credits: body.lines.filter(l => l.direction === 'CREDIT').reduce((sum, l) => sum + l.amount_cents, 0),
      net: convertedLines.reduce((sum, l) => sum + l.amount_cents, 0)
    };

    // Call the post_balanced_transaction RPC function
    const { data: txnId, error: postingError } = await supabaseAdmin
      .rpc('post_balanced_transaction', {
        p_user: user.id,
        p_idem: body.idempotency_key,
        p_lines: convertedLines,
        p_meta: body.meta || {}
      });

    if (postingError) {
      console.error('Posting error:', postingError);
      return new Response(JSON.stringify({ 
        error: "Failed to post transaction", 
        details: postingError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Return the posting response
    const response: PostingResponse = {
      txn_id: txnId,
      posted_at: new Date().toISOString(),
      totals
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
