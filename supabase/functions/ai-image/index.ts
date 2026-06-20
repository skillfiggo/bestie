/**
 * ai-image Edge Function
 *
 * Generates a personalized photo from an AI companion using xAI's image API.
 * - Authenticates user via JWT
 * - Deducts 50 coins per image (server-side billing)
 * - Fetches AI profile avatar and uses it as a reference image for visual consistency
 * - Calls xAI image generation API with the avatar as a character reference
 * - Returns the image URL
 *
 * Request body:
 *   { ai_profile_id: string, user_prompt?: string }
 *
 * Response:
 *   { image_url: string, coins_remaining: number }
 */

import { verifyAuth, corsResponse, errorResponse, successResponse } from '../_shared/auth.ts'

const XAI_GENERATIONS_URL = 'https://api.x.ai/v1/images/generations'
const XAI_EDITS_URL = 'https://api.x.ai/v1/images/edits'
const IMAGE_COST = 50  // coins per AI image

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

    // 3. Fetch AI profile — include avatar_url for character-consistent generation
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
    if (currentCoins < IMAGE_COST) {
      return errorResponse(`Insufficient coins. Photos cost ${IMAGE_COST} coins.`, 402)
    }

    const { error: deductErr } = await supabaseAdmin
      .from('profiles')
      .update({ coins: currentCoins - IMAGE_COST })
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

    // 6. Fetch the avatar image and convert to base64 for character consistency
    let referenceImageB64: string | null = null
    const avatarUrl: string = aiProfile.avatar_url ?? ''

    if (avatarUrl) {
      try {
        // Build the full public URL if it's a Supabase storage path
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const fullAvatarUrl = avatarUrl.startsWith('http')
          ? avatarUrl
          : `${supabaseUrl}/storage/v1/object/public/${avatarUrl}`

        console.log('Fetching avatar for reference:', fullAvatarUrl)

        const imgRes = await fetch(fullAvatarUrl)
        if (imgRes.ok) {
          const buffer = await imgRes.arrayBuffer()
          const bytes = new Uint8Array(buffer)

          // Convert ArrayBuffer to base64 in chunks to avoid stack overflow
          const chunkSize = 8192
          let binary = ''
          for (let i = 0; i < bytes.length; i += chunkSize) {
            binary += String.fromCharCode(...bytes.slice(i, i + chunkSize))
          }
          referenceImageB64 = btoa(binary)
          console.log('Avatar fetched and encoded, size:', referenceImageB64.length)
        } else {
          console.warn('Avatar fetch failed:', imgRes.status)
        }
      } catch (e) {
        // Non-fatal — fall back to text-prompt-only generation
        console.warn('Could not load avatar for reference image:', e)
      }
    }

    // 7. Build image prompt
    // Use avatar_description if set, otherwise derive from name + personality
    const characterDescription = aiProfile.avatar_description ||
      `a beautiful young woman named ${aiProfile.name}, attractive, photorealistic`

    // Clean up conversational prefixes from user prompt so it focuses purely on the description/setting
    let cleanPrompt = user_prompt?.trim() ?? ''
    if (cleanPrompt) {
      const patternsToRemove = [
        /send me a (picture|photo|image|pic|pix) of you/gi,
        /send me a (picture|photo|image|pic|pix) of/gi,
        /send me (picture|photo|image|pic|pix) of/gi,
        /send (picture|photo|image|pic|pix) of/gi,
        /show me a (picture|photo|image|pic|pix) of you/gi,
        /show me a (picture|photo|image|pic|pix) of/gi,
        /show me (picture|photo|image|pic|pix) of/gi,
        /show (picture|photo|image|pic|pix) of/gi,
        /a (picture|photo|image|pic|pix) of you/gi,
        /a (picture|photo|image|pic|pix) of/gi,
        /(picture|photo|image|pic|pix) of you/gi,
        /(picture|photo|image|pic|pix) of/gi,
        /send me a/gi,
        /send me/gi,
        /show me/gi,
        /picture/gi,
        /photo/gi,
        /image/gi,
        /pic/gi,
        /pix/gi,
      ]
      
      for (const pattern of patternsToRemove) {
        cleanPrompt = cleanPrompt.replace(pattern, '')
      }
      
      // Remove leading/trailing commas, spaces, or extra punctuation
      cleanPrompt = cleanPrompt.replace(/^[\s,.;!?]+|[\s,.;!?]+$/g, '').trim()
    }

    // Build separate prompts for Edit vs Generation
    // When editing an existing image (image-to-image), we do NOT include the detailed facial description
    // to prevent the edit model from redrawing or altering the existing face.
    const editPrompt = cleanPrompt
      ? `${cleanPrompt}, photorealistic, same person, high quality`
      : `selfie photo, smiling, photorealistic, same person, high quality`

    // When generating from scratch (fallback or no avatar), we need the full character description
    const generationPrompt = cleanPrompt
      ? `${characterDescription}, ${cleanPrompt}, photorealistic, high quality, natural skin, soft lighting`
      : `${characterDescription}, selfie photo, warm natural lighting, smiling, high quality portrait, photorealistic, high quality, natural skin, soft lighting`

    // Call Grok LLM to rewrite and enhance the prompt by combining the user request with character description
    let rewrittenPrompt = ''
    if (user_prompt?.trim()) {
      console.log('Calling Grok LLM to rewrite prompt...')
      try {
        const rewriteResponse = await fetch('https://api.x.ai/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${XAI_API_KEY}`,
          },
          body: JSON.stringify({
            model: 'grok-4.3',
            messages: [
              {
                role: 'system',
                content: `You are an expert prompt engineer for image generation. Your job is to take a user's image request and a character's physical description, and combine them into a single, cohesive, rich, and highly descriptive second-person image generation prompt.

Follow these rules:
1. Merge the user's action/setting request with the character's physical features.
2. Structure the prompt to address the character in the second person (e.g., "Please send me a picture of yourself wearing a summer dress. You have short, tightly curled black hair, striking bright red eyes, and deep dark brown skin...").
3. Do not include any introductory, explanatory, or concluding text. Output ONLY the rewritten prompt text itself.
4. IMPORTANT: The xAI developer API has strict content filters on swimwear/bikinis and exposed skin. If the user request asks for swimwear, swimsuit, bikini, or suggestive attire, smartly rewrite it using clean, stylish, PG-13 summer wear alternatives (e.g., "wearing a classy sundress at the beach", "wearing a stylish summer dress", "wearing a crop top and shorts") to prevent the generated image from being blocked by content moderation.`
              },
              {
                role: 'user',
                content: `User Request: ${user_prompt.trim()}\nAvatar Description: ${characterDescription}`
              }
            ],
            temperature: 0.7,
          }),
        })

        if (rewriteResponse.ok) {
          const rewriteData = await rewriteResponse.json()
          const resultText = rewriteData.choices?.[0]?.message?.content?.trim()
          if (resultText) {
            rewrittenPrompt = resultText
            console.log('Rewritten prompt successfully:', rewrittenPrompt)
          }
        } else {
          console.warn('Grok rewrite API call failed, status:', rewriteResponse.status)
        }
      } catch (e) {
        console.warn('Error rewriting prompt with Grok:', e)
      }
    }

    // 8. Call xAI image generation API
    // If we have a reference image, we use the /images/edits endpoint and pass the image object.
    // Otherwise, we use the /images/generations endpoint.
    const requestBody: Record<string, unknown> = {
      model: 'grok-imagine-image',
      n: 1,
      response_format: 'url',
    }

    let targetUrl = XAI_GENERATIONS_URL
    const targetPrompt = rewrittenPrompt || (referenceImageB64 ? editPrompt : generationPrompt)

    if (referenceImageB64) {
      targetUrl = XAI_EDITS_URL
      requestBody['prompt'] = targetPrompt
      requestBody['image'] = {
        url: `data:image/jpeg;base64,${referenceImageB64}`,
        type: 'image_url'
      }
    } else {
      requestBody['prompt'] = targetPrompt
    }

    console.log(`Sending image request to: ${targetUrl} using model: ${requestBody.model}`)

    let imageResponse = await fetch(targetUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${XAI_API_KEY}`,
      },
      body: JSON.stringify(requestBody),
    })

    let imageData: any = null

    if (!imageResponse.ok) {
      const errBody = await imageResponse.text()
      console.error('xAI primary image API error:', imageResponse.status, errBody)

      // Fallback: If we tried with a reference image and it failed (for any reason, e.g. RLS storage load errors,
      // safety filters, or API schema mismatch), retry immediately using text-only generation.
      if (referenceImageB64) {
        console.log('Retrying with generations endpoint using reference_images...')
        const fallbackBody = {
          model: 'grok-imagine-image',
          prompt: rewrittenPrompt || generationPrompt,
          n: 1,
          response_format: 'url',
          reference_images: [
            {
              url: `data:image/jpeg;base64,${referenceImageB64}`
            }
          ]
        }

        const fallbackResponse = await fetch(XAI_GENERATIONS_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${XAI_API_KEY}`,
          },
          body: JSON.stringify(fallbackBody),
        })

        if (fallbackResponse.ok) {
          imageResponse = fallbackResponse
          imageData = await fallbackResponse.json()
        } else {
          const fallbackErrBody = await fallbackResponse.text()
          console.error('xAI fallback image API error:', fallbackResponse.status, fallbackErrBody)
        }
      }
    } else {
      imageData = await imageResponse.json()
    }

    if (!imageResponse.ok || !imageData) {
      // Refund coins on failure
      await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
      return errorResponse('Photo service temporarily unavailable. Coins refunded.', 502)
    }

    const imageUrl = imageData.data?.[0]?.url

    if (!imageUrl) {
      await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
      return errorResponse('Failed to generate image. Coins refunded.', 500)
    }

    // 9. Return the image URL
    return successResponse({
      image_url: imageUrl,
      coins_remaining: currentCoins - IMAGE_COST,
    })

  } catch (err) {
    if (err instanceof Response) return err
    console.error('ai-image error:', err)
    return errorResponse('Internal server error', 500)
  }
})
