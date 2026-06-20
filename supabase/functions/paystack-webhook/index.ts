import {
  corsResponse,
  makeAdminClient,
  getCoinsForAmount,
  errorResponse,
  successResponse,
} from '_shared/auth.ts'
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts"

// ── Paystack webhook IP allowlist ─────────────────────────────────────────────
// Source: https://paystack.com/docs/payments/webhooks
// Valid for both test and live environments.
// Check these periodically — Paystack may add new IPs.
const PAYSTACK_IPS = new Set([
  '52.31.139.75',
  '52.49.173.169',
  '52.214.14.220',
])

/**
 * Extract the originating IP from the request.
 *
 * Supabase Edge Functions run behind a CDN. The real client IP is forwarded
 * via standard headers. We prefer `x-real-ip` (set by the edge proxy) over
 * the first entry of `x-forwarded-for` which can be spoofed by the caller.
 */
function getClientIp(req: Request): string | null {
  return (
    req.headers.get('x-real-ip') ??
    req.headers.get('cf-connecting-ip') ??            // Cloudflare
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    null
  )
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return corsResponse()

  try {
    // ── 0. IP allowlist check (defence-in-depth) ──────────────────────────
    // The HMAC signature below is the cryptographic hard gate.
    // This IP check is a second layer — it logs mismatches so you can audit
    // unexpected sources even if the HMAC somehow passes.
    //
    // Switch HARD_FAIL to true to reject requests from unknown IPs outright.
    // Keep false in production until you've confirmed the header is reliable
    // for your Supabase region.
    const HARD_FAIL_ON_IP_MISMATCH = false

    const clientIp = getClientIp(req)
    if (clientIp && !PAYSTACK_IPS.has(clientIp)) {
      console.warn(`[webhook] Request from unexpected IP: ${clientIp}`)
      // Log to audit trail (non-fatal — makeAdminClient used internally)
      try {
        const adminForLog = makeAdminClient()
        await adminForLog.rpc('log_security_event', {
          p_actor_id:     null,
          p_action:       'webhook_unexpected_ip',
          p_target_id:    null,
          p_target_table: null,
          p_details:      JSON.stringify({ ip: clientIp, source: 'paystack-webhook' }),
          p_ip_hint:      clientIp,
        })
      } catch { /* logging must never break payment processing */ }

      if (HARD_FAIL_ON_IP_MISMATCH) {
        return errorResponse('Forbidden — IP not in Paystack allowlist', 403)
      }
    }

    // ── 1. Verify Paystack HMAC-SHA512 signature ──────────────────────────
    // Webhooks are not user-initiated, so JWT auth is not applicable.
    // Paystack signs the request body with your secret key — we verify that.
    const signature = req.headers.get('x-paystack-signature')
    if (!signature) return errorResponse('Missing Paystack signature', 400)

    const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
    if (!secretKey) return errorResponse('Server configuration error', 500)

    const body = await req.text()

    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secretKey),
      { name: 'HMAC', hash: 'SHA-512' },
      false,
      ['sign']
    )
    const signatureBuffer = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body))
    const computedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('')

    if (computedSignature !== signature) {
      return errorResponse('Invalid signature — request not from Paystack', 401)
    }

    // ── 2. Parse event ────────────────────────────────────────────────────
    const event = JSON.parse(body)

    if (event.event === 'charge.success') {
      const data           = event.data
      const reference      = data.reference
      const amountPaidNaira = data.amount / 100
      const customerEmail  = data.customer.email

      // ── 3. Determine coin reward ────────────────────────────────────────
      const coinsToAdd = getCoinsForAmount(amountPaidNaira)
      if (coinsToAdd === 0) {
        console.log(`Webhook: Amount ₦${amountPaidNaira} below minimum — ignoring`)
        // Still return 200 so Paystack doesn't retry
        return successResponse({ received: true })
      }

      const supabaseAdmin = makeAdminClient()

      // ── 4. Look up user by email ────────────────────────────────────────
      const { data: userId, error: lookupError } = await supabaseAdmin
        .rpc('get_user_id_by_email', { p_email: customerEmail })

      if (lookupError || !userId) {
        console.error('Webhook: User not found for email:', customerEmail, lookupError)
        await supabaseAdmin.rpc('log_payment_attempt', {
          p_reference:     reference,
          p_email:         customerEmail,
          p_user_id:       null,
          p_amount:        amountPaidNaira,
          p_coins:         coinsToAdd,
          p_provider:      'paystack-webhook',
          p_success:       false,
          p_error_message: `User not found for email: ${customerEmail}`,
        }).catch((e: unknown) => console.error('Failed to log:', e))

        return successResponse({ received: true, error: 'User not found' })
      }

      // ── 5. Process payment ──────────────────────────────────────────────
      const { error: rpcError } = await supabaseAdmin.rpc('process_successful_payment', {
        p_user_id:   userId,
        p_reference: reference,
        p_amount:    amountPaidNaira,
        p_coins:     coinsToAdd,
        p_provider:  'paystack-webhook',
      })

      const success = !rpcError
      if (rpcError) {
        console.error('Webhook: RPC error:', rpcError.message)
      } else {
        console.log(`Webhook: ✅ Credited ${coinsToAdd} coins to user ${userId}`)
      }

      await supabaseAdmin.rpc('log_payment_attempt', {
        p_reference:     reference,
        p_email:         customerEmail,
        p_user_id:       userId,
        p_amount:        amountPaidNaira,
        p_coins:         coinsToAdd,
        p_provider:      'paystack-webhook',
        p_success:       success,
        p_error_message: rpcError?.message ?? null,
      }).catch((e: unknown) => console.error('Failed to log:', e))
    }

    // Always return 200 to Paystack to prevent retries
    return successResponse({ received: true })

  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error'
    console.error('Webhook error:', message)
    // Still 200 — prevents Paystack retrying a non-transient error
    return successResponse({ received: true, error: message })
  }
})
