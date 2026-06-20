/**
 * ai-describe-avatar Edge Function
 *
 * Takes an AI companion's avatar image and uses Grok Vision to produce
 * a detailed physical appearance description suitable for image generation prompts.
 * Only callable by admin users.
 *
 * Request body:
 *   { image: string }  — base64 data URL (data:image/...;base64,...) or public URL
 *
 * Response:
 *   { description: string }
 */

import { verifyAdminRole, corsResponse, errorResponse, successResponse } from '../_shared/auth.ts'

const XAI_CHAT_API_URL = 'https://api.x.ai/v1/chat/completions'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return corsResponse()

  try {
    // Only admins can use this endpoint
    await verifyAdminRole(req)

    const { image } = await req.json()
    if (!image || typeof image !== 'string') {
      return errorResponse('Missing image field')
    }

    const XAI_API_KEY = Deno.env.get('XAI_API_KEY')
    if (!XAI_API_KEY) {
      return errorResponse('AI service not configured', 500)
    }

    // Build the image content block — supports both data URLs and public URLs
    const imageContent = image.startsWith('data:')
      ? { type: 'image_url', image_url: { url: image, detail: 'high' } }
      : { type: 'image_url', image_url: { url: image, detail: 'high' } }

    // Ask Grok Vision for a precise appearance description
    const visionResponse = await fetch(XAI_CHAT_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${XAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'grok-4.3',
        messages: [
          {
            role: 'user',
            content: [
              imageContent,
              {
                type: 'text',
                text: `Describe this person's physical appearance in detail for use as an AI image generation prompt. Focus only on: hair color and style, eye color, skin tone, face shape, facial features (nose, lips, eyebrows), age estimate, and any distinctive features. Write it as a concise comma-separated list of descriptors, like: "long dark brown wavy hair, almond-shaped dark brown eyes, warm light-brown skin, heart-shaped face, full lips, high cheekbones, delicate nose, appears 22-25 years old". Do NOT include clothing, background, or personality. Keep it under 60 words.`,
              },
            ],
          },
        ],
        max_tokens: 150,
        temperature: 0.2,
      }),
    })

    if (!visionResponse.ok) {
      const errBody = await visionResponse.text()
      console.error('Grok Vision error:', visionResponse.status, errBody)
      return errorResponse('Vision analysis failed. Please try again.', 502)
    }

    const visionData = await visionResponse.json()
    const description = visionData.choices?.[0]?.message?.content?.trim()

    if (!description) {
      return errorResponse('Could not generate description from image', 500)
    }

    return successResponse({ description })

  } catch (err) {
    if (err instanceof Response) return err
    console.error('ai-describe-avatar error:', err)
    return errorResponse('Internal server error', 500)
  }
})
