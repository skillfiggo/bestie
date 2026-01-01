# Supabase Edge Function Deployment Script
# Run this in PowerShell from your project root directory

# Step 1: Login to Supabase
Write-Host "Step 1: Logging in to Supabase..." -ForegroundColor Green
supabase login

# Step 2: Link to your project
Write-Host "`nStep 2: Linking to your Supabase project..." -ForegroundColor Green
Write-Host "Please enter your Supabase Project Reference ID (from Dashboard > Settings > General):" -ForegroundColor Yellow
$projectRef = Read-Host "Project Reference ID"
supabase link --project-ref $projectRef

# Step 3: Set Agora credentials
Write-Host "`nStep 3: Setting Agora credentials..." -ForegroundColor Green
Write-Host "Please enter your Agora App ID (from Agora Console):" -ForegroundColor Yellow
$agoraAppId = Read-Host "Agora App ID"
Write-Host "Please enter your Agora App Certificate (from Agora Console > Project Management > Config):" -ForegroundColor Yellow
$agoraCertificate = Read-Host "Agora App Certificate"

supabase secrets set AGORA_APP_ID=$agoraAppId
supabase secrets set AGORA_APP_CERTIFICATE=$agoraCertificate

# Step 4: Deploy the Edge Function
Write-Host "`nStep 4: Deploying Edge Function..." -ForegroundColor Green
supabase functions deploy generate-agora-token

Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
Write-Host "Your Agora token generation function is now live!" -ForegroundColor Cyan
