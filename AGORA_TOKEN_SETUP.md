# Agora Token Generation Setup

This guide explains how to deploy the Agora token generation Edge Function to Supabase.

## Prerequisites

1. **Supabase CLI** installed
2. **Agora Account** with App ID and App Certificate
3. **Supabase Project** set up

## Step 1: Get Your Agora Credentials

1. Go to [Agora Console](https://console.agora.io/)
2. Select your project
3. Copy your **App ID**
4. Go to **Project Management** → **Config**
5. Copy your **Primary Certificate** (or generate one if you don't have it)

## Step 2: Set Environment Variables in Supabase

Run these commands in your terminal (replace with your actual values):

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Set Agora credentials as secrets
supabase secrets set AGORA_APP_ID=your_agora_app_id_here
supabase secrets set AGORA_APP_CERTIFICATE=your_agora_app_certificate_here
```

## Step 3: Deploy the Edge Function

```bash
# Deploy the function
supabase functions deploy generate-agora-token
```

## Step 4: Test the Function

You can test the function using curl:

```bash
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/generate-agora-token' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"channelName": "test-channel", "uid": 0}'
```

## Step 5: Update Your Flutter App

The Flutter app is already configured to use this Edge Function. Just make sure:

1. Your `.env` file has the correct `SUPABASE_URL` and `SUPABASE_ANON_KEY`
2. Hot restart the app after deploying the function

## Troubleshooting

### "Missing Agora credentials in environment"
- Make sure you ran the `supabase secrets set` commands
- Redeploy the function after setting secrets

### "Unauthorized" error
- Check that the user is logged in
- Verify the Authorization header is being sent

### Token still showing as "EMPTY"
- Check the console logs for "🔑 Fetching Agora token..."
- Verify the Edge Function is deployed and accessible

## Security Notes

- Tokens expire after 1 hour (configurable in `index.ts`)
- Only authenticated users can request tokens
- Each user can only join channels they're authorized for
- The App Certificate is never exposed to the client

## Local Development

To test locally:

```bash
# Serve the function locally
supabase functions serve generate-agora-token --env-file ./supabase/.env.local

# Create .env.local with your credentials
echo "AGORA_APP_ID=your_app_id" >> supabase/.env.local
echo "AGORA_APP_CERTIFICATE=your_certificate" >> supabase/.env.local
```
