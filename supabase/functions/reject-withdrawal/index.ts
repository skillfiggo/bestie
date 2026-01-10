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

        // 1. Initialize Admin Supabase
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 2. Identify Admin User
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Unauthorized')

        const userClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )
        const { data: { user } } = await userClient.auth.getUser()

        const { data: profile } = await supabaseAdmin.from('profiles').select('role').eq('id', user?.id).single()
        if (profile?.role !== 'admin') throw new Error('Only admins can reject withdrawals')

        // 3. Get Request Details
        const { data: withdrawal, error: fetchErr } = await supabaseAdmin
            .from('withdrawal_requests')
            .select('*')
            .eq('id', id)
            .single()

        if (fetchErr || !withdrawal) throw new Error('Withdrawal request not found')
        if (withdrawal.status !== 'pending') throw new Error('Request already processed')

        // 4. Update Status and REFUND Diamonds
        // We use a transaction-like approach or just direct updates since we are on the server

        // Update request
        await supabaseAdmin
            .from('withdrawal_requests')
            .update({
                status: 'rejected',
                admin_notes: notes ?? 'Rejected by Admin'
            })
            .eq('id', id)

        // Refund diamonds to user
        await supabaseAdmin.rpc('increment_diamonds', {
            p_user_id: withdrawal.user_id,
            p_amount: withdrawal.amount_diamonds
        })

        // 5. Notify User
        const reason = notes ? ` Reason: ${notes}` : '';
        const msg = `❌ Withdrawal Rejected. ${withdrawal.amount_diamonds} diamonds have been refunded to your wallet.${reason}`;

        await supabaseAdmin.rpc('send_official_message', {
            target_user_id: withdrawal.user_id,
            message_content: msg
        });

        return new Response(JSON.stringify({ success: true }), {
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
