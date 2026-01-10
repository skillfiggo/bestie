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
        const { id, notes } = await req.json()
        const secretKey = Deno.env.get('PAYSTACK_SECRET_KEY')
        if (!secretKey) throw new Error('Missing PAYSTACK_SECRET_KEY')

        // 1. Initialize Admin Supabase
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 2. Identify Admin User calling this
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Unauthorized')

        const userClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )
        const { data: { user } } = await userClient.auth.getUser()

        // Check if user is admin
        const { data: profile } = await supabaseAdmin.from('profiles').select('role').eq('id', user?.id).single()
        if (profile?.role !== 'admin') throw new Error('Only admins can approve withdrawals')

        // 3. Get Request Details
        const { data: withdrawal, error: fetchErr } = await supabaseAdmin
            .from('withdrawal_requests')
            .select('*')
            .eq('id', id)
            .single()

        if (fetchErr || !withdrawal) throw new Error('Withdrawal request not found')
        if (withdrawal.status !== 'pending') throw new Error('Request already processed')

        // 4. Create Paystack Transfer Recipient
        const recipientRes = await fetch('https://api.paystack.co/transferrecipient', {
            method: 'POST',
            headers: {
                Authorization: `Bearer ${secretKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                type: "nuban",
                name: withdrawal.account_name,
                account_number: withdrawal.account_number,
                bank_code: withdrawal.bank_code,
                currency: "NGN"
            })
        })

        const recipientData = await recipientRes.json()
        if (!recipientData.status) throw new Error(`Recipient creation failed: ${recipientData.message}`)

        const recipientCode = recipientData.data.recipient_code

        // 5. Initiate Transfer
        const transferRes = await fetch('https://api.paystack.co/transfer', {
            method: 'POST',
            headers: {
                Authorization: `Bearer ${secretKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                source: "balance",
                amount: Math.round(withdrawal.amount_naira * 100), // Convert to kobo
                recipient: recipientCode,
                reason: "Bestie Creator Payout",
                reference: `wdr_${withdrawal.id.split('-')[0]}_${Date.now()}`
            })
        })

        const transferData = await transferRes.json()
        if (!transferData.status) throw new Error(`Transfer initiation failed: ${transferData.message}`)

        // 6. Update Database
        await supabaseAdmin
            .from('withdrawal_requests')
            .update({
                status: 'processing', // or 'completed' depending on your flow
                paystack_transfer_code: transferData.data.transfer_code,
                admin_notes: notes ?? 'Approved by Admin'
            })
            .eq('id', id)

        // 7. Notify User
        const amount = withdrawal.amount_naira.toLocaleString('en-NG', { style: 'currency', currency: 'NGN' });
        const notificationMsg = `✅ Withdrawal Approved! Your withdrawal of ${amount} has been processed and sent to your bank.`;

        await supabaseAdmin.rpc('send_official_message', {
            target_user_id: withdrawal.user_id,
            message_content: notificationMsg
        });

        return new Response(JSON.stringify({ success: true, data: transferData.data }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        return new Response(JSON.stringify({ error: message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
