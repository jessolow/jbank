// Transaction History Edge Function
// Returns paginated timeline for auth.uid() with filters { from, to, type }
// Queries the history.timeline_by_customer view

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS"
};

interface HistoryFilters {
  from?: string; // ISO date string
  to?: string;   // ISO date string
  type?: string; // Event type filter
  page?: number; // Page number (1-based)
  limit?: number; // Items per page
}

interface TimelineItem {
  customer_id: string;
  date: string;
  type: string;
  amounts: Record<string, any>;
  refs: Record<string, any>;
}

interface HistoryResponse {
  items: TimelineItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    total_pages: number;
    has_next: boolean;
    has_prev: boolean;
  };
  filters: HistoryFilters;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Check if it's a GET request
    if (req.method !== "GET") {
      return new Response(JSON.stringify({ 
        error: "Method not allowed. Only GET is supported." 
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

    // Parse query parameters
    const url = new URL(req.url);
    const filters: HistoryFilters = {
      from: url.searchParams.get('from') || undefined,
      to: url.searchParams.get('to') || undefined,
      type: url.searchParams.get('type') || undefined,
      page: parseInt(url.searchParams.get('page') || '1'),
      limit: Math.min(parseInt(url.searchParams.get('limit') || '50'), 100) // Max 100 items per page
    };

    // Validate date formats if provided
    if (filters.from && !isValidDate(filters.from)) {
      return new Response(JSON.stringify({ 
        error: "Invalid 'from' date format. Use ISO date (YYYY-MM-DD)" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    if (filters.to && !isValidDate(filters.to)) {
      return new Response(JSON.stringify({ 
        error: "Invalid 'to' date format. Use ISO date (YYYY-MM-DD)" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Validate page and limit
    if (filters.page! < 1) {
      return new Response(JSON.stringify({ 
        error: "Page number must be 1 or greater" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    if (filters.limit! < 1 || filters.limit! > 100) {
      return new Response(JSON.stringify({ 
        error: "Limit must be between 1 and 100" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Build the query for timeline_by_customer view
    let query = supabaseAdmin
      .from('history.timeline_by_customer')
      .select('*')
      .eq('customer_id', user.id);

    // Apply date filters
    if (filters.from) {
      query = query.gte('date', filters.from);
    }
    if (filters.to) {
      query = query.lte('date', filters.to);
    }

    // Apply type filter
    if (filters.type) {
      query = query.eq('type', filters.type);
    }

    // Get total count for pagination
    const { count, error: countError } = await query.count();
    
    if (countError) {
      console.error('Count error:', countError);
      return new Response(JSON.stringify({ 
        error: "Failed to get total count", 
        details: countError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    const total = count || 0;
    const totalPages = Math.ceil(total / filters.limit!);
    const offset = (filters.page! - 1) * filters.limit!;

    // Get paginated results
    const { data: timelineItems, error: queryError } = await query
      .order('date', { ascending: false })
      .order('type', { ascending: true })
      .range(offset, offset + filters.limit! - 1);

    if (queryError) {
      console.error('Query error:', queryError);
      return new Response(JSON.stringify({ 
        error: "Failed to fetch timeline data", 
        details: queryError.message 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      });
    }

    // Build response
    const response: HistoryResponse = {
      items: timelineItems || [],
      pagination: {
        page: filters.page!,
        limit: filters.limit!,
        total,
        total_pages: totalPages,
        has_next: filters.page! < totalPages,
        has_prev: filters.page! > 1
      },
      filters
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

// Helper function to validate date format
function isValidDate(dateString: string): boolean {
  const date = new Date(dateString);
  return date instanceof Date && !isNaN(date.getTime()) && dateString.match(/^\d{4}-\d{2}-\d{2}$/);
}
