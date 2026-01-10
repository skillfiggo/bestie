import { serve } from "http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { email, amount, reference } = await req.json()

        const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
        if (!secretKey) throw new Error('Server configuration error: Missing Secret Key')

        // Initialize transaction with Paystack
        const initResponse = await fetch('https://api.paystack.co/transaction/initialize', {
            method: 'POST',
            headers: {
                Authorization: `Bearer ${secretKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                email,
                amount, // Already in kobo
                reference,
                currency: 'NGN',
                callback_url: 'https://your-app.com/payment-callback' // Not used but required
            })
        })

        const initData = await initResponse.json()

        if (!initResponse.ok || !initData.status) {
            throw new Error(initData.message || 'Failed to initialize payment')
        }

        return new Response(JSON.stringify(initData), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        return new Response(JSON.stringify({ error: message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400
        })
    }
})
