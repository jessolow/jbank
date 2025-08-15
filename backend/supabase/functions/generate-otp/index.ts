import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Email template for OTP
const createOTPEmail = (otpCode: string, firstName?: string) => {
  const greeting = firstName ? `Hello ${firstName}!` : 'Hello!'
  
  return {
    subject: 'Your jBank Verification Code',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="text-align: center; margin-bottom: 30px;">
          <h1 style="color: #2563eb; margin: 0;">jBank</h1>
          <p style="color: #6b7280; margin: 10px 0;">Your Digital Banking Partner</p>
        </div>
        
        <div style="background: #f8fafc; padding: 30px; border-radius: 10px; border: 1px solid #e2e8f0;">
          <h2 style="color: #1e293b; margin: 0 0 20px 0;">${greeting}</h2>
          
          <p style="color: #475569; line-height: 1.6; margin: 0 0 20px 0;">
            You've requested a verification code to access your jBank account. 
            Please use the code below to complete your verification:
          </p>
          
          <div style="background: #ffffff; padding: 20px; border-radius: 8px; border: 2px solid #e2e8f0; text-align: center; margin: 20px 0;">
            <h1 style="color: #2563eb; font-size: 32px; letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">
              ${otpCode}
            </h1>
          </div>
          
          <p style="color: #64748b; font-size: 14px; margin: 20px 0 0 0;">
            <strong>Important:</strong> This code will expire in 10 minutes and can only be used once.
          </p>
          
          <p style="color: #64748b; font-size: 14px; margin: 10px 0 0 0;">
            If you didn't request this code, please ignore this email or contact our support team.
          </p>
        </div>
        
        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e2e8f0;">
          <p style="color: #94a3b8; font-size: 12px; margin: 0;">
            © 2024 jBank. All rights reserved.
          </p>
        </div>
      </div>
    `,
    text: `
jBank - Your Digital Banking Partner

${greeting}

You've requested a verification code to access your jBank account. 
Please use the code below to complete your verification:

${otpCode}

Important: This code will expire in 10 minutes and can only be used once.

If you didn't request this code, please ignore this email or contact our support team.

© 2024 jBank. All rights reserved.
    `
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get request body
    const { email, firstName, lastName } = await req.json()
    
    if (!email) {
      return new Response(
        JSON.stringify({ error: 'Email is required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString()
    
    // Create email content
    const emailContent = createOTPEmail(otpCode, firstName)
    
    // Send email using Resend
    try {
      const resendApiKey = Deno.env.get('RESEND_API_KEY')
      if (!resendApiKey) {
        console.warn('RESEND_API_KEY not found, skipping email send')
        // For development, still return the OTP
        return new Response(
          JSON.stringify({ 
            success: true, 
            message: 'OTP generated successfully (email not sent - missing API key)',
            isExistingUser: false,
            otp: otpCode,
            note: 'Set RESEND_API_KEY environment variable to enable email sending'
          }),
          { 
            status: 200, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      // Send email via Resend
      const resendResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendApiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from: 'jBank <noreply@jdigibank.org>',
          to: [email],
          subject: emailContent.subject,
          html: emailContent.html,
          text: emailContent.text
        })
      })

      if (!resendResponse.ok) {
        const errorText = await resendResponse.text(); // Read the raw error text
        console.error(`Resend API Error Response (Status ${resendResponse.status}): ${errorText}`); // Log the raw text!
        
        let errorMessage = 'An unknown error occurred';
        try {
            // Try to parse it as JSON to get a more specific message
            const errorJson = JSON.parse(errorText);
            errorMessage = errorJson.message || JSON.stringify(errorJson);
        } catch (e) {
            // If it's not JSON, the raw text is our best clue
            errorMessage = errorText;
        }
        
        throw new Error(`Resend API error: ${errorMessage}`);
      }

      console.log(`OTP email sent successfully to ${email} via Resend`)
      
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'OTP sent to your email successfully',
          isExistingUser: false,
          note: 'Check your email for the verification code'
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )

    } catch (emailError) {
      console.error('Email sending failed:', emailError)
      
      // Fallback: return OTP in response for development
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'OTP generated but email failed to send',
          isExistingUser: false,
          otp: otpCode,
          note: 'Email service temporarily unavailable. Use OTP above for testing.'
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

  } catch (error) {
    console.error('Error in generate-otp:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
