import { createClient } from '@supabase/supabase-js'
import { crypto } from 'https://deno.land/std@0.177.0/crypto/mod.ts'
import { encode } from 'https://deno.land/std@0.177.0/encoding/hex.ts'

/**
 * Paystack Transfer Approval URL
 * 
 * Paystack calls this endpoint BEFORE processing any transfer.
 * We must respond with { status: true } to approve or { status: false } to reject.
 * 
 * Paystack docs: https://paystack.com/docs/transfers/transfer-approval/
 */
Deno.serve(async (req: Request) => {
    // Paystack only sends POST requests here
    if (req.method !== 'POST') {
        return new Response(JSON.stringify({ status: false }), {
            headers: { 'Content-Type': 'application/json' },
            status: 405,
        })
    }

    try {
        const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
        if (!secretKey) {
            console.error('Missing PAYSTACK_SECRET_KEY')
            return new Response(JSON.stringify({ status: false }), {
                headers: { 'Content-Type': 'application/json' },
                status: 200, // Always return 200 to Paystack, use status field to approve/reject
            })
        }

        // ── Verify Paystack Signature ────────────────────────────────────────
        const rawBody = await req.text()
        const paystackSignature = req.headers.get('x-paystack-signature') ?? ''

        const key = await crypto.subtle.importKey(
            'raw',
            new TextEncoder().encode(secretKey),
            { name: 'HMAC', hash: 'SHA-512' },
            false,
            ['sign']
        )
        const signatureBuffer = await crypto.subtle.sign(
            'HMAC',
            key,
            new TextEncoder().encode(rawBody)
        )
        const computedSignature = new TextDecoder().decode(encode(new Uint8Array(signatureBuffer)))

        if (computedSignature !== paystackSignature) {
            console.error('Invalid Paystack signature — rejecting transfer')
            return new Response(JSON.stringify({ status: false }), {
                headers: { 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // ── Parse the Transfer Payload ───────────────────────────────────────
        const payload = JSON.parse(rawBody)
        const { reference, amount, recipient } = payload

        console.log(`Transfer approval request: ref=${reference}, amount=${amount}, recipient=${recipient?.details?.account_number}`)

        // ── Check Against Our Database ───────────────────────────────────────
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Look up the withdrawal request by the transfer reference
        const { data: withdrawal, error } = await supabaseAdmin
            .from('withdrawal_requests')
            .select('id, status, amount_naira, paystack_transfer_code')
            .or(`paystack_transfer_code.eq.${reference},id.eq.${reference.split('_')[1] ?? ''}`)
            .single()

        if (error || !withdrawal) {
            // If we can't find the record, reject for safety
            console.warn(`No matching withdrawal for ref=${reference}. Rejecting.`)
            return new Response(JSON.stringify({ status: false }), {
                headers: { 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // Verify the withdrawal is in 'processing' state (i.e., admin already approved it)
        if (withdrawal.status !== 'processing') {
            console.warn(`Withdrawal ${withdrawal.id} is not in processing state (status=${withdrawal.status}). Rejecting.`)
            return new Response(JSON.stringify({ status: false }), {
                headers: { 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // Verify the amount matches (Paystack amount is in kobo)
        const expectedAmountKobo = Math.round(withdrawal.amount_naira * 100)
        if (amount !== expectedAmountKobo) {
            console.error(`Amount mismatch: expected ${expectedAmountKobo} kobo, got ${amount} kobo. Rejecting.`)
            return new Response(JSON.stringify({ status: false }), {
                headers: { 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // ── All checks passed — Approve the Transfer ─────────────────────────
        console.log(`✅ Approving transfer for withdrawal ${withdrawal.id}`)
        return new Response(JSON.stringify({ status: true }), {
            headers: { 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (err) {
        console.error('Transfer approval error:', err)
        // On unexpected errors, reject the transfer to be safe
        return new Response(JSON.stringify({ status: false }), {
            headers: { 'Content-Type': 'application/json' },
            status: 200,
        })
    }
})
