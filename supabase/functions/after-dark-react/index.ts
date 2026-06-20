/**
 * after-dark-react  Edge Function
 *
 * Handles paid reactions to After Dark stories:
 *   - super_like   : 20 coins  → 12 diamonds (60%) to story author
 *   - super_comment: 50 coins  → 30 diamonds to story author
 *   - gift_100     : 100 coins → 60 diamonds to story author
 *   - gift_200     : 200 coins → 120 diamonds to story author
 *
 * Free "like" is handled directly on the client (no coins involved).
 *
 * Request body:
 *   { story_id: string, type: 'super_like'|'super_comment'|'gift_100'|'gift_200', message?: string }
 *
 * Response:
 *   { success: true, coins_remaining: number, diamonds_awarded: number }
 */

import { verifyAuth, corsResponse, errorResponse, successResponse } from '../_shared/auth.ts'

const REACTION_CONFIG: Record<string, { coinCost: number; diamondAward: number; label: string }> = {
  super_like:    { coinCost: 20,  diamondAward: 12,  label: 'Super Like'    },
  super_comment: { coinCost: 50,  diamondAward: 30,  label: 'Super Comment' },
  gift_100:      { coinCost: 100, diamondAward: 60,  label: 'Story Gift'    },
  gift_200:      { coinCost: 200, diamondAward: 120, label: 'Grand Gift'    },
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return corsResponse()

  try {
    const { user, supabaseAdmin } = await verifyAuth(req)
    const { story_id, type, message } = await req.json()

    if (!story_id || !type) return errorResponse('Missing story_id or type')

    const config = REACTION_CONFIG[type]
    if (!config) return errorResponse(`Unknown reaction type: ${type}`)

    // 1. Fetch story — ensure it exists and is approved
    const { data: story, error: storyErr } = await supabaseAdmin
      .from('after_dark_stories')
      .select('id, user_id, status')
      .eq('id', story_id)
      .single()

    if (storyErr || !story) return errorResponse('Story not found', 404)
    if (story.status !== 'approved') return errorResponse('Story not yet available', 403)
    if (story.user_id === user.id) return errorResponse('Cannot react to your own story', 403)

    // 2. Check sender's coin balance
    const { data: sender, error: senderErr } = await supabaseAdmin
      .from('profiles')
      .select('coins')
      .eq('id', user.id)
      .single()

    if (senderErr || !sender) return errorResponse('Could not fetch your profile', 500)
    if ((sender.coins ?? 0) < config.coinCost) {
      return errorResponse(`Insufficient coins. ${config.label} costs ${config.coinCost} coins.`, 402)
    }

    // 3. Deduct coins from sender
    const { error: deductErr } = await supabaseAdmin
      .from('profiles')
      .update({ coins: sender.coins - config.coinCost })
      .eq('id', user.id)

    if (deductErr) return errorResponse('Failed to deduct coins', 500)

    try {
      // 4a. super_like → insert into reactions + increment count
      if (type === 'super_like') {
        await supabaseAdmin.from('after_dark_reactions').upsert({
          story_id,
          user_id: user.id,
          type: 'super_like',
        })
        await supabaseAdmin.rpc('increment_story_likes', {
          p_story_id: story_id,
          p_type: 'super_like',
        })
      }

      // 4b. super_comment / gift → insert into gifts table
      if (type === 'super_comment' || type === 'gift_100' || type === 'gift_200') {
        await supabaseAdmin.from('after_dark_gifts').insert({
          story_id,
          sender_id: user.id,
          gift_type: type,
          coin_cost: config.coinCost,
          message: message ?? null,
        })
      }

      // 5. Award diamonds to story author (60% of coin cost)
      await supabaseAdmin.rpc('award_after_dark_diamonds', {
        p_story_id:  story_id,
        p_diamonds:  config.diamondAward,
      })

    } catch (innerErr) {
      // Refund coins on any inner failure
      console.error('after-dark-react inner error:', innerErr)
      await supabaseAdmin
        .from('profiles')
        .update({ coins: sender.coins })
        .eq('id', user.id)
      return errorResponse('Reaction failed. Coins refunded.', 500)
    }

    return successResponse({
      success: true,
      coins_remaining: sender.coins - config.coinCost,
      diamonds_awarded: config.diamondAward,
    })

  } catch (err) {
    if (err instanceof Response) return err
    console.error('after-dark-react error:', err)
    return errorResponse('Internal server error', 500)
  }
})
