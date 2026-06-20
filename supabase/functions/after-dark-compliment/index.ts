/**
 * after-dark-compliment  Edge Function
 *
 * Sends an anonymous compliment on an After Dark story.
 * - Deducts 10 coins from sender
 * - Inserts into after_dark_compliments (sender identity never exposed to recipient)
 * - Notifies story owner via push notification (no sender info in message)
 *
 * Request body:
 *   { story_id: string, message: string }
 *
 * Response:
 *   { success: true, coins_remaining: number }
 */

import { verifyAuth, corsResponse, errorResponse, successResponse } from '../_shared/auth.ts'

const COMPLIMENT_COST = 10

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return corsResponse()

  try {
    const { user, supabaseAdmin } = await verifyAuth(req)
    const { story_id, message } = await req.json()

    if (!story_id || !message?.trim()) {
      return errorResponse('Missing story_id or message')
    }

    if (message.trim().length > 200) {
      return errorResponse('Message too long (max 200 characters)')
    }

    // 1. Fetch story
    const { data: story, error: storyErr } = await supabaseAdmin
      .from('after_dark_stories')
      .select('id, user_id, is_anonymous, status')
      .eq('id', story_id)
      .single()

    if (storyErr || !story) return errorResponse('Story not found', 404)
    if (story.status !== 'approved') return errorResponse('Story not yet available', 403)
    if (story.user_id === user.id) return errorResponse('Cannot compliment your own story', 403)

    // 2. Check coins
    const { data: sender } = await supabaseAdmin
      .from('profiles')
      .select('coins')
      .eq('id', user.id)
      .single()

    if (!sender || (sender.coins ?? 0) < COMPLIMENT_COST) {
      return errorResponse(`Insufficient coins. Anonymous compliments cost ${COMPLIMENT_COST} coins.`, 402)
    }

    // 3. Deduct coins
    const { error: deductErr } = await supabaseAdmin
      .from('profiles')
      .update({ coins: sender.coins - COMPLIMENT_COST })
      .eq('id', user.id)

    if (deductErr) return errorResponse('Failed to deduct coins', 500)

    // 4. Insert compliment (service role — RLS bypassed)
    const { error: insertErr } = await supabaseAdmin
      .from('after_dark_compliments')
      .insert({
        story_id,
        sender_id: user.id,
        message:   message.trim(),
        coin_cost: COMPLIMENT_COST,
      })

    if (insertErr) {
      // Refund
      await supabaseAdmin
        .from('profiles')
        .update({ coins: sender.coins })
        .eq('id', user.id)
      return errorResponse('Failed to send compliment. Coins refunded.', 500)
    }

    // 5. Push notification to story owner — no sender identity revealed
    try {
      const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
      const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
      await fetch(`${SUPABASE_URL}/functions/v1/send-notification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          user_id: story.user_id,
          title:   '💌 Anonymous Compliment',
          body:    'Someone sent you a secret compliment on your After Dark story!',
          data:    { type: 'after_dark_compliment', story_id },
        }),
      })
    } catch (notifErr) {
      // Non-fatal
      console.warn('Notification failed:', notifErr)
    }

    return successResponse({
      success: true,
      coins_remaining: sender.coins - COMPLIMENT_COST,
    })

  } catch (err) {
    if (err instanceof Response) return err
    console.error('after-dark-compliment error:', err)
    return errorResponse('Internal server error', 500)
  }
})
