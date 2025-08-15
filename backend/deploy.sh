#!/bin/bash

# J Bank Backend Deployment Script
# Deploys all Edge Functions to Supabase

set -e

echo "🚀 Starting J Bank Backend deployment..."

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed. Please install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "supabase/config.toml" ]; then
    echo "❌ Please run this script from the backend directory"
    exit 1
fi

# Start Supabase if not running
echo "📡 Starting Supabase..."
supabase start

# Wait for Supabase to be ready
echo "⏳ Waiting for Supabase to be ready..."
sleep 10

# Deploy all Edge Functions
echo "🔧 Deploying Edge Functions..."

echo "  📋 Deploying Customer Master Service..."
supabase functions deploy customer-master

echo "  💰 Deploying Deposit Core Service..."
supabase functions deploy deposit-core

echo "  🏦 Deploying Lending Core Service..."
supabase functions deploy lending-core

echo "  📊 Deploying Transaction History Service..."
supabase functions deploy transaction-history

echo "  ✅ Deploying Complete Profile Service..."
supabase functions deploy complete-profile

echo "  🔐 Deploying Handle OAuth User Service..."
supabase functions deploy handle-oauth-user

echo "  🔍 Deploying Check User Exists Service..."
supabase functions deploy check-user-exists

echo "  📧 Deploying Generate OTP Service..."
supabase functions deploy generate-otp

echo "  🔑 Deploying Verify OTP Service..."
supabase functions deploy verify-otp

# Apply database migrations
echo "🗄️  Applying database migrations..."
supabase db push

echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployed Services:"
echo "  • Customer Master Service"
echo "  • Deposit Core Service"
echo "  • Lending Core Service"
echo "  • Transaction History Service"
echo "  • Complete Profile Service"
echo "  • Handle OAuth User Service"
echo "  • Check User Exists Service"
echo "  • Generate OTP Service"
echo "  • Verify OTP Service"
echo ""
echo "🌐 Your Supabase instance is running at:"
echo "   Dashboard: http://localhost:54323"
echo "   API: http://localhost:54321"
echo "   Database: postgresql://postgres:postgres@localhost:54322/postgres"
echo ""
echo "📚 Next steps:"
echo "   1. Set up your environment variables"
echo "   2. Test the API endpoints"
echo "   3. Configure your frontend to use these services"
echo ""
echo "🔗 For more information, see the README.md file"
