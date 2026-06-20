/**
 * ai-video Edge Function
 *
 * Generates a short personalised video from an AI companion using xAI's video API.
 * - Authenticates user via JWT
 * - Deducts 150 coins per video (server-side billing)
 * - Fetches AI profile avatar and uses it as the starting frame (image-to-video)
 * - Calls xAI grok-imagine-video (async) and polls for the result
 * - Returns the video URL once generation is complete
 *
 * Request body:
 *   { ai_profile_id: string, user_prompt?: string }
 *
 * Response:
 *   { video_url: string, coins_remaining: number }
 */

import { verifyAuth, corsResponse, errorResponse, successResponse } from '../_shared/auth.ts'

const XAI_VIDEO_GENERATIONS_URL = 'https://api.x.ai/v1/videos/generations'
const XAI_VIDEO_STATUS_BASE_URL  = 'https://api.x.ai/v1/videos'
const VIDEO_COST = 150           // coins per AI video
const POLL_INTERVAL_MS = 5000    // 5 seconds between polls
const MAX_POLL_ATTEMPTS = 36     // 36 × 5s = 3 minutes max wait

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return corsResponse()

  try {
    // 1. Authenticate
    const { user, supabaseAdmin } = await verifyAuth(req)

    // 2. Parse request body
    const { ai_profile_id, user_prompt } = await req.json()

    if (!ai_profile_id) {
      return errorResponse('Missing ai_profile_id')
    }

    // 3. Fetch AI profile — include avatar_url for the starting frame
    const { data: aiProfile, error: profileErr } = await supabaseAdmin
      .from('ai_profiles')
      .select('name, personality, is_active, avatar_url, avatar_description')
      .eq('id', ai_profile_id)
      .single()

    if (profileErr || !aiProfile) {
      return errorResponse('AI profile not found', 404)
    }

    if (!aiProfile.is_active) {
      return errorResponse('This AI companion is currently unavailable', 403)
    }

    // 4. Check & deduct coins
    const { data: userProfile, error: profileFetchErr } = await supabaseAdmin
      .from('profiles')
      .select('coins')
      .eq('id', user.id)
      .single()

    if (profileFetchErr || !userProfile) {
      return errorResponse('Could not fetch user profile', 500)
    }

    const currentCoins = userProfile.coins ?? 0
    if (currentCoins < VIDEO_COST) {
      return errorResponse(`Insufficient coins. Videos cost ${VIDEO_COST} coins.`, 402)
    }

    const { error: deductErr } = await supabaseAdmin
      .from('profiles')
      .update({ coins: currentCoins - VIDEO_COST })
      .eq('id', user.id)

    if (deductErr) {
      return errorResponse('Failed to process payment', 500)
    }

    // 5. Check API key
    const XAI_API_KEY = Deno.env.get('XAI_API_KEY')
    if (!XAI_API_KEY) {
      await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
      return errorResponse('AI service not configured', 500)
    }

    // 6. Fetch avatar image as base64 for the starting frame
    let referenceImageB64: string | null = null
    const avatarUrl: string = aiProfile.avatar_url ?? ''

    if (avatarUrl) {
      try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const fullAvatarUrl = avatarUrl.startsWith('http')
          ? avatarUrl
          : `${supabaseUrl}/storage/v1/object/public/${avatarUrl}`

        console.log('Fetching avatar for video starting frame:', fullAvatarUrl)

        const imgRes = await fetch(fullAvatarUrl)
        if (imgRes.ok) {
          const buffer = await imgRes.arrayBuffer()
          const bytes = new Uint8Array(buffer)

          // Convert to base64 in chunks to avoid stack overflow
          const chunkSize = 8192
          let binary = ''
          for (let i = 0; i < bytes.length; i += chunkSize) {
            binary += String.fromCharCode(...bytes.slice(i, i + chunkSize))
          }
          referenceImageB64 = btoa(binary)
          console.log('Avatar encoded for video, size:', referenceImageB64.length)
        } else {
          console.warn('Avatar fetch failed:', imgRes.status)
        }
      } catch (e) {
        console.warn('Could not load avatar for starting frame:', e)
      }
    }

    // 7. Build video prompt
    const characterDescription = aiProfile.avatar_description ||
      `a beautiful young woman named ${aiProfile.name}, attractive, photorealistic`

    // Clean user prompt of request-style prefixes
    let cleanPrompt = user_prompt?.trim() ?? ''
    if (cleanPrompt) {
      const patternsToRemove = [
        /send me a (video|clip|reel) of you/gi,
        /send me a (video|clip|reel) of/gi,
        /send me (video|clip|reel) of/gi,
        /show me a (video|clip|reel) of you/gi,
        /show me a (video|clip|reel) of/gi,
        /show me (video|clip|reel) of/gi,
        /send me a/gi,
        /send me/gi,
        /show me/gi,
        /video/gi,
        /clip/gi,
        /reel/gi,
      ]
      for (const pattern of patternsToRemove) {
        cleanPrompt = cleanPrompt.replace(pattern, '')
      }
      cleanPrompt = cleanPrompt.replace(/^[\s,.;!?]+|[\s,.;!?]+$/g, '').trim()
    }

    const motionPrompt = cleanPrompt
      ? `${characterDescription}, ${cleanPrompt}, slow cinematic motion, soft natural lighting, photorealistic, high quality`
      : `${characterDescription}, smiling warmly, hair gently moving, slow cinematic push-in, soft natural lighting, photorealistic`

    console.log('Video motion prompt:', motionPrompt)

    // 8. Submit video generation job (async API — returns request_id immediately)
    const requestBody: Record<string, unknown> = {
      model: 'grok-imagine-video',
      prompt: motionPrompt,
      duration: 5,
      n: 1,
    }

    // Pass the avatar as the starting frame if available
    if (referenceImageB64) {
      requestBody['image'] = {
        url: `data:image/jpeg;base64,${referenceImageB64}`,
        type: 'image_url',
      }
    }

    console.log('Submitting video job to xAI...')

    const submitResponse = await fetch(XAI_VIDEO_GENERATIONS_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${XAI_API_KEY}`,
      },
      body: JSON.stringify(requestBody),
    })

    if (!submitResponse.ok) {
      const errBody = await submitResponse.text()
      console.error('xAI video submit error:', submitResponse.status, errBody)
      await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
      return errorResponse('Video service temporarily unavailable. Coins refunded.', 502)
    }

    const submitData = await submitResponse.json()
    const requestId: string = submitData.request_id ?? submitData.id

    if (!requestId) {
      console.error('No request_id in submit response:', JSON.stringify(submitData))
      await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
      return errorResponse('Video service error: no job ID returned. Coins refunded.', 500)
    }

    console.log('Video job submitted, request_id:', requestId)

    // 9. Poll for completion
    const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

    for (let attempt = 1; attempt <= MAX_POLL_ATTEMPTS; attempt++) {
      await sleep(POLL_INTERVAL_MS)

      const statusResponse = await fetch(`${XAI_VIDEO_STATUS_BASE_URL}/${requestId}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${XAI_API_KEY}`,
        },
      })

      if (!statusResponse.ok) {
        console.warn(`Poll attempt ${attempt} failed:`, statusResponse.status)
        continue
      }

      const statusData = await statusResponse.json()
      const status: string = statusData.status ?? ''

      console.log(`Poll attempt ${attempt}, status: ${status}`)

      if (status === 'done' || status === 'succeeded' || status === 'completed') {
        // Try multiple known response shapes
        const videoUrl: string =
          statusData.video?.url ??
          statusData.data?.[0]?.url ??
          statusData.url ??
          ''

        if (!videoUrl) {
          console.error('Status is done but no video URL in response:', JSON.stringify(statusData))
          await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
          return errorResponse('Video generated but URL missing. Coins refunded.', 500)
        }

        console.log('Video ready:', videoUrl)
        return successResponse({
          video_url: videoUrl,
          coins_remaining: currentCoins - VIDEO_COST,
        })
      }

      if (status === 'failed' || status === 'error') {
        console.error('Video job failed:', JSON.stringify(statusData))
        await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
        return errorResponse('Video generation failed. Coins refunded.', 502)
      }

      if (status === 'expired') {
        console.error('Video job expired')
        await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
        return errorResponse('Video generation timed out. Coins refunded.', 504)
      }

      // status is 'pending' or 'processing' — keep polling
    }

    // Max polls exceeded
    console.error('Max poll attempts reached for request_id:', requestId)
    await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
    return errorResponse('Video took too long to generate. Coins refunded.', 504)

  } catch (err) {
    if (err instanceof Response) return err
    console.error('ai-video error:', err)
    return errorResponse('Internal server error', 500)
  }
})
