// Agora RTC Token Builder
// Based on: https://github.com/AgoraIO/Tools/tree/master/DynamicKey/AgoraDynamicKey

const VERSION = '007'
export const ROLE_PUBLISHER = 1
export const ROLE_SUBSCRIBER = 2

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

export async function buildToken(
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
            1: privilegeExpiredTs, // kJoinChannel
            2: privilegeExpiredTs, // kPublishAudioStream
            3: privilegeExpiredTs, // kPublishVideoStream
            4: privilegeExpiredTs, // kPublishDataStream
        }
    }

    // Pack message
    const packedMessage = new Uint8Array([
        ...packUint32(message.salt),
        ...packUint32(message.ts),
        ...packMapUint32(message.messages),
    ])

    // Generate signature
    const signature = await hmacSign(appCertificate, packedMessage)

    // Pack content
    const content = new Uint8Array([
        ...packString(appId),
        ...packString(channelName),
        ...packString(uid.toString()),
        ...packedMessage,
    ])

    // Pack signature
    const signaturePacked = new Uint8Array([
        ...packString(base64Encode(signature)),
        ...content,
    ])

    // Encode to base64
    const token = VERSION + base64Encode(signaturePacked)

    return token
}
