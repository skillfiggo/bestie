# Security Hardening Configuration Guide

This document outlines the final manual steps required to fully secure your application. These changes happen outside of your codebase, in the respective dashboards of the services you use.

## 1. Paystack Webhook IP Allowlisting

By default, any server could theoretically send fake successful payment events to your `paystack-webhook` endpoint. While we have signature verification in place, adding an IP allowlist provides defense-in-depth against DDoS.

**Steps:**
1. Log into your **Paystack Dashboard**.
2. Go to **Settings > API Keys & Webhooks**.
3. Under the webhook URL section, you will see an option to restrict by IP (depending on your Paystack integration/plan). If you don't see it, Paystack guarantees their signature header (`x-paystack-signature`) which we are already validating.
4. **Ensure the Webhook URL** is correctly pointed to your Supabase edge function:
   `https://[PROJECT_REF].supabase.co/functions/v1/paystack-webhook`

## 2. Supabase Rate Limiting (Dashboard)

As you are on the **Free Plan**, you do not have access to the advanced Network Rate Limiting features of Supabase. However, we have implemented custom rate-limiting in the database (`api_rate_limits` table) which covers your edge functions.

**What you *can* configure:**
1. Log into your **Supabase Dashboard**.
2. Go to **Authentication > Rate Limits**.
3. Set reasonable limits for:
   - Email signups (e.g., 5 per hour per IP)
   - OTP requests
   - Password resets
   This prevents bots from spamming your auth endpoints.

## 3. JWT Expiry

Shorter JWT expiry times reduce the window of opportunity if a token is ever compromised.

**Steps:**
1. In the **Supabase Dashboard**, go to **Authentication > Advanced**.
2. Find the **JWT expiry** setting.
3. Change it from the default (usually 3600 seconds or 86400 seconds) to `3600` (1 hour) if it isn't already.
4. The Flutter client handles token refreshing automatically via the Supabase SDK.

## 4. App Store Integrity (Future Phase)

Currently, the app uses basic Jailbreak/Root detection (`flutter_jailbreak_detection`).
When you are ready to launch seriously, consider implementing:
- **Android Play Integrity API**: Verifies the app was installed from Google Play and hasn't been modified.
- **iOS DeviceCheck**: Similar integrity checking for Apple devices.

## 5. Web Admin Panel (Future Phase)

When you move your admin panel to `www.bestieeapp.xyz`:
1. Open `supabase/functions/_shared/auth.ts`.
2. Change the `Access-Control-Allow-Origin` from `'*'` to `'https://www.bestieeapp.xyz'`.
3. Put the domain behind **Cloudflare** for edge DDoS protection.
