/**
 * ai-chat Edge Function
 * 
 * Handles AI companion chat powered by xAI's Grok API.
 * - Authenticates user via JWT
 * - Deducts 10 coins per message (server-side billing)
 * - Fetches AI profile personality (system prompt)
 * - Calls Grok API with conversation history
 * - Returns AI response
 * 
 * Request body:
 *   { ai_profile_id: string, messages: Array<{role: string, content: string}>, new_message: string }
 * 
 * Response:
 *   { reply: string }
 */

import { verifyAuth, corsHeaders, corsResponse, errorResponse, successResponse } from '../_shared/auth.ts'

const XAI_API_URL = 'https://api.x.ai/v1/chat/completions'
const MESSAGE_COST = 10  // coins per AI message

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return corsResponse()
  }

  try {
    // 1. Authenticate
    const { user, supabaseAdmin } = await verifyAuth(req)

    // 2. Parse request body
    const { ai_profile_id, messages, new_message } = await req.json()

    if (!ai_profile_id || !new_message || typeof new_message !== 'string') {
      return errorResponse('Missing ai_profile_id or new_message')
    }

    if (new_message.trim().length === 0) {
      return errorResponse('Message cannot be empty')
    }

    // 3. Fetch AI profile personality
    const { data: aiProfile, error: profileErr } = await supabaseAdmin
      .from('ai_profiles')
      .select('name, personality, is_active')
      .eq('id', ai_profile_id)
      .single()

    if (profileErr || !aiProfile) {
      return errorResponse('AI profile not found', 404)
    }

    if (!aiProfile.is_active) {
      return errorResponse('This AI companion is currently unavailable', 403)
    }

    // 4. Deduct coins (server-side billing)
    const { data: userProfile, error: profileFetchErr } = await supabaseAdmin
      .from('profiles')
      .select('coins, gender')
      .eq('id', user.id)
      .single()

    if (profileFetchErr || !userProfile) {
      return errorResponse('Could not fetch user profile', 500)
    }

    const currentCoins = userProfile.coins ?? 0

    if (currentCoins < MESSAGE_COST) {
      return errorResponse(`Insufficient coins. AI messages cost ${MESSAGE_COST} coins.`, 402)
    }

    // Deduct coins
    const { error: deductErr } = await supabaseAdmin
      .from('profiles')
      .update({ coins: currentCoins - MESSAGE_COST })
      .eq('id', user.id)

    if (deductErr) {
      console.error('Failed to deduct coins:', deductErr)
      return errorResponse('Failed to process payment', 500)
    }

    // 5. Build Grok API request
    const XAI_API_KEY = Deno.env.get('XAI_API_KEY')
    if (!XAI_API_KEY) {
      // Refund coins if API key is not configured
      await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
      return errorResponse('AI service not configured', 500)
    }

    // Build conversation history for Grok
    const conversationMessages = [
      {
        role: 'system',
        content: aiProfile.personality || `You are ${aiProfile.name}, a friendly and engaging AI companion. Be warm, playful, and conversational. Keep responses concise (2-3 sentences max). Never break character.`
      },
      // Include recent conversation history from client
      ...(Array.isArray(messages) ? messages.slice(-20) : []),
      // Add the new user message
      { role: 'user', content: new_message }
    ]

    // 6. Call Grok API
    const grokResponse = await fetch(XAI_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${XAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'grok-4.3',
        messages: conversationMessages,
        max_tokens: 300,
        temperature: 0.8,
      }),
    })

    if (!grokResponse.ok) {
      const errBody = await grokResponse.text()
      console.error('Grok API error:', grokResponse.status, errBody)
      // Refund coins on API failure
      await supabaseAdmin.from('profiles').update({ coins: currentCoins }).eq('id', user.id)
      return errorResponse('AI service temporarily unavailable. Coins refunded.', 502)
    }

    const grokData = await grokResponse.json()
    const aiReply = grokData.choices?.[0]?.message?.content ?? 'Sorry, I couldn\'t think of a response.'

    // 7. Return reply
    return successResponse({
      reply: aiReply,
      coins_remaining: currentCoins - MESSAGE_COST,
    })

  } catch (err) {
    // If err is already a Response (from verifyAuth), pass it through
    if (err instanceof Response) return err
    console.error('ai-chat error:', err)
    return errorResponse('Internal server error', 500)
  }
})
