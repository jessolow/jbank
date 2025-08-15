# Manual Edge Function Deployment Guide

Since the CLI has Docker quota issues, deploy these functions through your Supabase dashboard.

## 📋 **Deployment Steps**

1. **Go to your Supabase dashboard**: https://supabase.com/dashboard/project/navolchoccoxcjkkwkcb
2. **Click "Edge Functions"** in the left sidebar
3. **For each function below, click "Create function"**

## 🔧 **Functions to Deploy**

### 1. **customer-master**
- **Function name**: `customer-master`
- **Copy the code from**: `supabase/functions/customer-master/index.ts`

### 2. **deposit-core**
- **Function name**: `deposit-core`
- **Copy the code from**: `supabase/functions/deposit-core/index.ts`

### 3. **lending-core**
- **Function name**: `lending-core`
- **Copy the code from**: `supabase/functions/lending-core/index.ts`

### 4. **transaction-history**
- **Function name**: `transaction-history`
- **Copy the code from**: `supabase/functions/transaction-history/index.ts`

## ⚠️ **Important Notes**

- **Import paths need to be updated** for dashboard deployment
- **Remove the relative imports** (../../../types/index.ts, etc.)
- **Copy the utility functions** directly into each function file
- **Or create shared utility functions** in the dashboard

## 🎯 **Quick Test After Deployment**

Once deployed, test with:
```bash
curl -X POST https://navolchoccoxcjkkwkcb.supabase.co/functions/v1/customer-master/create \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## 📚 **Next Steps After Deployment**

1. **Apply database schema** (SQL files)
2. **Test all endpoints**
3. **Configure frontend integration**
