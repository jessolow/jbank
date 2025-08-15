import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { display_name, phone_number } = await req.json();

    if (!display_name) {
      throw new Error("Display name is required");
    }

    // Get the JWT token from the Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    console.log('Auth header received:', authHeader.substring(0, 50) + '...');

    // Extract the token from "Bearer <token>"
    const token = authHeader.replace('Bearer ', '');
    if (!token) {
      throw new Error('Invalid authorization header format');
    }

    console.log('Token extracted:', token.substring(0, 50) + '...');

    // Create Supabase admin client with service role key
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    console.log('Supabase URL:', supabaseUrl);
    console.log('Service Role Key:', serviceRoleKey.substring(0, 20) + '...');
    
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

    // Verify the JWT token and extract user info
    console.log('Verifying JWT token...');
    const { data: { user }, error: verifyError } = await supabaseAdmin.auth.getUser(token);
    
    if (verifyError) {
      console.error('JWT verification error:', verifyError);
      throw new Error(`Invalid JWT token: ${verifyError.message}`);
    }
    
    if (!user) {
      console.error('No user found from JWT');
      throw new Error('No user found from JWT');
    }

    console.log(`Completing profile for user: ${user.email} (ID: ${user.id})`);

    // Update the user's metadata using admin privileges
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      user.id,
      {
        user_metadata: {
          display_name: display_name,
          phone_number: phone_number,
        }
      }
    );

    if (updateError) {
      console.error("Update user metadata error:", updateError);
      throw updateError;
    }

    console.log('Profile updated successfully');

    return new Response(JSON.stringify({ 
      success: true, 
      message: "Profile updated", 
      user_id: user.id, 
      display_name: display_name 
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Function error:", error);
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
