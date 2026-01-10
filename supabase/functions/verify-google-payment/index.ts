
import { serve } from "http/server.ts"
import { createClient } from '@supabase/supabase-js'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// COIN RATES CONFIGURATION
// Ensure these match the Flutter client mappings
const PRODUCT_COINS_MAP: Record<string, number> = {
    'bestie_coins_tier1': 1200,
    'bestie_coins_tier2': 2000,
    'bestie_coins_tier3': 5000,
    'bestie_coins_tier4': 10000,
};

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { source, verificationData, productID, transactionID } = await req.json()

        if (source !== 'google_play') {
            throw new Error('Invalid source')
        }

        // 1. VERIFY WITH GOOGLE (Simplified/Stubbed)
        // In a real production app, you MUST validate 'verificationData' (the purchase token)
        // using the Google Play Developer API:
        // GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}
        // This requires a Service Account with access to the Play Console.

        // For this implementation, we will perform a basic check that data exists.
        if (!verificationData || !productID || !transactionID) {
            throw new Error('Missing verification data');
        }

        // 2. Determine Coins based on Product ID (Server-side source of truth)
        const coinsToAdd = PRODUCT_COINS_MAP[productID];
        if (!coinsToAdd) {
            throw new Error(`Unknown Product ID: ${productID}`);
        }

        // 3. Initialize Admin Supabase Client
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 4. Identify User
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) throw new Error('Missing Authorization header')

        const userClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        const { data: { user }, error: userError } = await userClient.auth.getUser()
        if (userError || !user) throw new Error('Unauthorized user')

        // 5. Record Transaction & Fund Wallet
        // We use the same 'process_successful_payment' RPC but with 'google_play' provider
        // Note: For Google Play, 'transactionID' is effectively the 'reference'

        const { data, error: rpcError } = await supabaseAdmin.rpc('process_successful_payment', {
            p_user_id: user.id,
            p_reference: `gp_${transactionID}`, // Prefix to ensure uniqueness/context
            p_amount: 0, // We might not know the exact price paid in USD/NGN here without the API call, setting 0 or handling differently.
            p_coins: coinsToAdd,
            p_provider: 'google_play'
        })

        if (rpcError) {
            // Handle duplicate transaction error specifically if needed
            if (rpcError.message.includes('unique constraint')) {
                // Already processed, return success (idempotency)
                return new Response(JSON.stringify({
                    success: true,
                    message: "Transaction already processed",
                    coinsAdded: 0
                }), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    status: 200
                })
            }
            throw new Error(`Database error: ${rpcError.message}`)
        }

        return new Response(JSON.stringify({
            success: true,
            coinsAdded: coinsToAdd,
            newBalance: data
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
