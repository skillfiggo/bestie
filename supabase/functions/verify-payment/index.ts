import { createClient } from '@supabase/supabase-js'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { reference } = await req.json()

        // 1. Get Secret Key
        // Note: User must set PAYSTACK_SECRET_KEY in Supabase Dashboard
        const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
        if (!secretKey) throw new Error('Server configuration error: Missing Secret Key')

        // 2. Verify with Paystack
        const verifyRes = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
            headers: {
                Authorization: `Bearer ${secretKey}`,
                'Content-Type': 'application/json'
            }
        })

        if (!verifyRes.ok) {
            throw new Error('Failed to contact payment provider')
        }

        const verifyData = await verifyRes.json()

        if (!verifyData.status || verifyData.data.status !== 'success') {
            throw new Error(`Payment verification failed: ${verifyData.message}`)
        }

        const amountPaidKobo = verifyData.data.amount
        const amountPaidNaira = amountPaidKobo / 100

        // 3. Determine Coins
        let coinsToAdd = 0
        // Package Logic (>= to handle potential small price changes or user overpaying slightly?)
        // Exact match is safer to prevent confusion, but floating point issues might occur.
        // Using ranges or "at least" logic.
        if (amountPaidNaira >= 17000) coinsToAdd = 10500
        else if (amountPaidNaira >= 8500) coinsToAdd = 5200
        else if (amountPaidNaira >= 3500) coinsToAdd = 2100
        else if (amountPaidNaira >= 1800) coinsToAdd = 1200 // 1000 + 200 Bonus
        else {
            throw new Error(`Amount N${amountPaidNaira} is below the minimum package price. Contact support.`)
        }

        // 4. Initialize Admin Supabase Client
        // We use the Service Role Key to bypass RLS and write to tables/profiles securely
        // But standard practices suggest using the Auth context if possible. 
        // However, updating coins is unrestricted for the user? NO, we moved that to server only.
        // So we need Service Role or a Postgres Function with `security definer`.
        // Edge Functions have access to `SUPABASE_SERVICE_ROLE_KEY`.
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 5. Identify User
        // We expect the user's JWT in the Authorization header
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Missing Authorization header')

        const userClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        const { data: { user }, error: userError } = await userClient.auth.getUser()
        if (userError || !user) throw new Error('Unauthorized user')

        // 6. Record Transaction & Fund Wallet
        // We call a Database Function (RPC) to do this atomically and prevent replay
        // Replay protection: The RPC should check if `reference` already exists in `payment_history`

        const { data, error: rpcError } = await supabaseAdmin.rpc('process_successful_payment', {
            p_user_id: user.id,
            p_reference: reference,
            p_amount: amountPaidNaira,
            p_coins: coinsToAdd,
            p_provider: 'paystack'
        })

        if (rpcError) {
            throw new Error(`Database error: ${rpcError.message}`)
        }

        return new Response(JSON.stringify({
            success: true,
            coinsAdded: coinsToAdd,
            newBalance: data // Assuming RPC returns new balance
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200
        })

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        return new Response(JSON.stringify({ error: message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400
        })
    }
})
