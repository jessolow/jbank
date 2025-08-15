import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get request body
    const { email, otpCode } = await req.json()
    
    if (!email || !otpCode) {
      return new Response(
        JSON.stringify({ error: 'Email and OTP code are required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // For now, let's create a simple response without database operations
    // This will help us test the function deployment first
    
    // Simulate OTP verification (we'll implement this later)
    const isValidOTP = otpCode.length === 6 && /^\d{6}$/.test(otpCode)
    
    if (!isValidOTP) {
      return new Response(
        JSON.stringify({ error: 'Invalid OTP code format' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }
    
    // Generate session token
    const sessionToken = crypto.randomUUID()
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString() // 24 hours
    
    // NOTE: Using snake_case for keys to match standard database conventions
    // This fixes the "missing data" decoding error on the client
    const mockUser = {
      id: crypto.randomUUID(),
      email: email,
      first_name: "User",
      last_name: "Account",
      is_verified: true,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'OTP verified successfully',
        user: mockUser,
        sessionToken,
        expiresAt,
        note: 'Database integration coming soon!'
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in verify-otp:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
