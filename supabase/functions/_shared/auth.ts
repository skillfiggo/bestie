/**
 * _shared/auth.ts
 *
 * Shared authentication, security, and response helpers for all Bestie edge functions.
 *
 * Usage:
 *   import { verifyAuth, verifyAdminRole, makeAdminClient,
 *            corsResponse, errorResponse, successResponse,
 *            getCoinsForAmount, validateAmountKobo, validateReference,
 *            COIN_PACKAGES } from '../_shared/auth.ts'
 */

import { createClient, SupabaseClient, User } from '@supabase/supabase-js'

// ─── Types ───────────────────────────────────────────────────────────────────

export interface AuthResult {
  user: User
  supabaseAdmin: SupabaseClient
}

export interface AdminAuthResult {
  user: User
  profile: { role: string }
  supabaseAdmin: SupabaseClient
}

// ─── Standard CORS headers ────────────────────────────────────────────────────
// For mobile-only apps CORS origin is * (Flutter ignores it).
// When the web admin panel launches at bestieeapp.xyz, change * to that domain.
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-paystack-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export function corsResponse(): Response {
  return new Response('ok', { headers: corsHeaders })
}

// ─── Supabase client factories ────────────────────────────────────────────────

/**
 * Returns a Supabase admin client using the service role key.
 * Use for server-side operations that need to bypass RLS (e.g. webhooks).
 */
export function makeAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )
}

// ─── Auth verification ────────────────────────────────────────────────────────

/**
 * Verifies the JWT in the Authorization header.
 * Returns the authenticated user and an admin Supabase client.
 * Throws a 401 Response if authentication fails.
 */
export async function verifyAuth(req: Request): Promise<AuthResult> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Response(
      JSON.stringify({ error: 'Missing or invalid Authorization header' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  const supabaseAdmin = makeAdminClient()

  const userClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error } = await userClient.auth.getUser()
  if (error || !user) {
    throw new Response(
      JSON.stringify({ error: 'Unauthorized: invalid or expired token' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  return { user, supabaseAdmin }
}

/**
 * Verifies the JWT and additionally checks that the caller has role = 'admin'
 * in the profiles table. Throws a 401 or 403 Response on failure.
 *
 * Use for admin-only endpoints (approve/reject withdrawals, etc.).
 */
export async function verifyAdminRole(req: Request): Promise<AdminAuthResult> {
  const { user, supabaseAdmin } = await verifyAuth(req)

  const { data: profile, error: profileErr } = await supabaseAdmin
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()

  if (profileErr || !profile) {
    throw new Response(
      JSON.stringify({ error: 'Could not verify user role' }),
      { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  if (profile.role !== 'admin') {
    throw new Response(
      JSON.stringify({ error: 'Forbidden: admin access required' }),
      { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  return { user, profile, supabaseAdmin }
}

// ─── Payment validation ───────────────────────────────────────────────────────

/** Valid coin packages: { amountNaira: coinsAwarded } */
export const COIN_PACKAGES: Record<number, number> = {
  1800:  1200,
  3500:  2100,
  8500:  5200,
  17000: 10500,
}

/**
 * Maps a paid naira amount to the correct coin reward.
 * Uses an epsilon comparison to handle floating-point edge cases.
 * Returns 0 if the amount doesn't match any package.
 */
export function getCoinsForAmount(amountNaira: number): number {
  const epsilon = 0.01
  if (amountNaira >= 17000 - epsilon) return 10500
  if (amountNaira >= 8500  - epsilon) return 5200
  if (amountNaira >= 3500  - epsilon) return 2100
  if (amountNaira >= 1800  - epsilon) return 1200
  return 0
}

/**
 * Validates that the requested payment amount matches a known package (in kobo).
 * Throws a 400 Response if invalid.
 */
export function validateAmountKobo(amountKobo: number): void {
  const validKoboAmounts = Object.keys(COIN_PACKAGES).map(n => parseInt(n) * 100)
  if (!validKoboAmounts.includes(amountKobo)) {
    throw new Response(
      JSON.stringify({ error: `Invalid amount. Must be one of: ${validKoboAmounts.join(', ')} kobo` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
}

// ─── Reference validation ─────────────────────────────────────────────────────

/**
 * Validates a payment reference format.
 * Expected: alphanumeric + hyphens/underscores, 8–64 chars.
 * Throws a 400 Response if invalid.
 */
export function validateReference(reference: string): void {
  if (!reference || !/^[a-zA-Z0-9_\-]{8,64}$/.test(reference)) {
    throw new Response(
      JSON.stringify({ error: 'Invalid payment reference format' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
}

// ─── Response helpers ─────────────────────────────────────────────────────────

export function errorResponse(message: string, status = 400): Response {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

export function successResponse(data: unknown, status = 200): Response {
  return new Response(
    JSON.stringify(data),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
