import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// Import official Agora token builder from npm via esm.sh
import { RtcTokenBuilder, RtcRole } from 'https://esm.sh/agora-access-token@2.0.4'

const AGORA_APP_ID = Deno.env.get('AGORA_APP_ID')!
const AGORA_APP_CERTIFICATE = Deno.env.get('AGORA_APP_CERTIFICATE')!

serve(async (req: Request) => {
    try {
        // CORS headers
        if (req.method === 'OPTIONS') {
            return new Response('ok', {
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST',
                    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
                },
            })
        }

        // Verify authentication
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
                status: 401,
                headers: { 'Content-Type': 'application/json' },
            })
        }

        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            {
                global: {
                    headers: { Authorization: authHeader },
                },
            }
        )

        // Verify user is authenticated
        const {
            data: { user },
            error: userError,
        } = await supabaseClient.auth.getUser()

        if (userError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                status: 401,
                headers: { 'Content-Type': 'application/json' },
            })
        }

        // Parse request body
        const { channelName, uid, role } = await req.json() as { channelName?: string; uid?: number; role?: number }

        if (!channelName) {
            return new Response(JSON.stringify({ error: 'Missing channelName' }), {
                status: 400,
                headers: { 'Content-Type': 'application/json' },
            })
        }

        // Validate environment variables
        if (!AGORA_APP_ID || !AGORA_APP_CERTIFICATE) {
            console.error('Missing Agora credentials in environment')
            return new Response(JSON.stringify({ error: 'Server configuration error' }), {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
            })
        }

        // Generate token using official Agora library
        const uidNum = uid || 0
        const roleNum = role || RtcRole.PUBLISHER
        const expirationTimeInSeconds = 3600 // 1 hour
        const currentTimestamp = Math.floor(Date.now() / 1000)
        const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

        console.log(`Generating token for user ${user.id}`)
        console.log(`Channel: ${channelName}`)
        console.log(`UID: ${uidNum}`)
        console.log(`Role: ${roleNum}`)
        console.log(`Current timestamp (seconds): ${currentTimestamp}`)
        console.log(`Privilege expires at (seconds): ${privilegeExpiredTs}`)
        console.log(`Time until expiry (seconds): ${privilegeExpiredTs - currentTimestamp}`)

        // Use official Agora token builder
        const token = RtcTokenBuilder.buildTokenWithUid(
            AGORA_APP_ID,
            AGORA_APP_CERTIFICATE,
            channelName,
            uidNum,
            roleNum,
            privilegeExpiredTs
        )

        console.log(`Token generated successfully, length: ${token.length}`)

        return new Response(
            JSON.stringify({
                token,
                appId: AGORA_APP_ID,
                channelName,
                uid: uidNum,
                expiresAt: privilegeExpiredTs,
            }),
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                },
            }
        )
    } catch (error: any) {
        console.error('Error generating token:', error)
        return new Response(JSON.stringify({ error: error.message || 'Internal server error' }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
        })
    }
})
