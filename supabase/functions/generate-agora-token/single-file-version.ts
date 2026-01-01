import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const AGORA_APP_ID = Deno.env.get('AGORA_APP_ID')!
const AGORA_APP_CERTIFICATE = Deno.env.get('AGORA_APP_CERTIFICATE')!

// ============================================
// Agora Token Builder (Inlined)
// ============================================
const VERSION = '007'
const ROLE_PUBLISHER = 1

function packUint16(num: number): Uint8Array {
    const buffer = new Uint8Array(2)
    buffer[0] = (num >> 8) & 0xff
    buffer[1] = num & 0xff
    return buffer
}

function packUint32(num: number): Uint8Array {
    const buffer = new Uint8Array(4)
    buffer[0] = (num >> 24) & 0xff
    buffer[1] = (num >> 16) & 0xff
    buffer[2] = (num >> 8) & 0xff
    buffer[3] = num & 0xff
    return buffer
}

function packString(str: string): Uint8Array {
    const strBytes = new TextEncoder().encode(str)
    const length = packUint16(strBytes.length)
    const result = new Uint8Array(length.length + strBytes.length)
    result.set(length)
    result.set(strBytes, length.length)
    return result
}

function packMapUint32(map: { [key: number]: number }): Uint8Array {
    const keys = Object.keys(map).map(Number).sort((a, b) => a - b)
    const length = packUint16(keys.length)

    const parts: Uint8Array[] = [length]
    for (const key of keys) {
        parts.push(packUint16(key))
        parts.push(packUint32(map[key]))
    }

    const totalLength = parts.reduce((sum, arr) => sum + arr.length, 0)
    const result = new Uint8Array(totalLength)
    let offset = 0
    for (const part of parts) {
        result.set(part, offset)
        offset += part.length
    }

    return result
}

async function hmacSign(key: string, message: Uint8Array): Promise<Uint8Array> {
    const encoder = new TextEncoder()
    const keyData = encoder.encode(key)

    const cryptoKey = await crypto.subtle.importKey(
        'raw',
        keyData,
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign']
    )

    const signature = await crypto.subtle.sign('HMAC', cryptoKey, message as any)
    return new Uint8Array(signature)
}

function base64Encode(data: Uint8Array): string {
    const binString = Array.from(data, (byte) => String.fromCodePoint(byte)).join('')
    return btoa(binString)
}

async function buildToken(
    appId: string,
    appCertificate: string,
    channelName: string,
    uid: number,
    role: number,
    privilegeExpiredTs: number
): Promise<string> {
    const message = {
        salt: Math.floor(Math.random() * 100000000),
        ts: Math.floor(Date.now() / 1000),
        messages: {
            1: privilegeExpiredTs,
            2: privilegeExpiredTs,
            3: privilegeExpiredTs,
            4: privilegeExpiredTs,
        }
    }

    const packedMessage = new Uint8Array([
        ...packUint32(message.salt),
        ...packUint32(message.ts),
        ...packMapUint32(message.messages),
    ])

    const signature = await hmacSign(appCertificate, packedMessage)

    const content = new Uint8Array([
        ...packString(appId),
        ...packString(channelName),
        ...packString(uid.toString()),
        ...packedMessage,
    ])

    const signaturePacked = new Uint8Array([
        ...packString(base64Encode(signature)),
        ...content,
    ])

    const token = VERSION + base64Encode(signaturePacked)

    return token
}

// ============================================
// Main Edge Function
// ============================================
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

        // Generate token
        const uidNum = uid || 0
        const roleNum = role || ROLE_PUBLISHER
        const expirationTimeInSeconds = 3600 // 1 hour
        const currentTimestamp = Math.floor(Date.now() / 1000)
        const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

        console.log(`Generating token for user ${user.id}, channel: ${channelName}, uid: ${uidNum}`)

        const token = await buildToken(
            AGORA_APP_ID,
            AGORA_APP_CERTIFICATE,
            channelName,
            uidNum,
            roleNum,
            privilegeExpiredTs
        )

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
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
        })
    }
})
