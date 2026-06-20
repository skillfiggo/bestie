import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { corsResponse, errorResponse, successResponse } from '_shared/auth.ts';
import { createClient } from '@supabase/supabase-js';

// ── Types ──────────────────────────────────────────────────────
interface BulkPayload {
  title: string;
  body: string;
  imageUrl?: string;
  filter: 'all' | 'inactive' | 'no_photo' | 'city';
  city?: string;
}

// ── Google OAuth2 (reused from send-notification) ─────────────
async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
  };
  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const signingInput = `${encode(header)}.${encode(payload)}`;
  const pemKey = serviceAccount.private_key.replace(/\\n/g, "\n");
  const cleaned = pemKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const keyBytes = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", keyBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signatureBytes = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(signingInput));
  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const jwt = `${signingInput}.${signature}`;
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) throw new Error(`OAuth2 failed: ${JSON.stringify(tokenData)}`);
  return tokenData.access_token;
}

// ── Send one FCM message ───────────────────────────────────────
async function sendOne(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
  projectId: string,
): Promise<boolean> {
  const message: Record<string, unknown> = {
    message: {
      token,
      notification: { title, body },
      android: { priority: "HIGH", notification: { channelId: "bestie_notifications", sound: "default" } },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
      data,
    },
  };
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify(message),
  });
  return res.ok;
}

// ── Main ──────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") return corsResponse();

  try {
    // 1. Verify caller is an authenticated admin
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return errorResponse("Missing Authorization", 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Decode JWT to get user
    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(jwt);
    if (authErr || !user) return errorResponse("Unauthorized", 401);

    // Check admin role
    const { data: profile } = await supabase
      .from("profiles").select("role").eq("id", user.id).single();
    if (profile?.role !== "admin") return errorResponse("Forbidden — admin only", 403);

    // 2. Parse body
    const { title, body, imageUrl, filter, city }: BulkPayload = await req.json();
    if (!title || !body || !filter) return errorResponse("title, body, filter are required", 400);
    if (title.length > 100 || body.length > 300) return errorResponse("title ≤100 chars, body ≤300 chars", 400);
    if (filter === "city" && !city) return errorResponse("city is required for city filter", 400);

    // 3. Build audience query
    let query = supabase.from("profiles").select("id, fcm_token")
      .not("fcm_token", "is", null);

    if (filter === "inactive") {
      const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
      query = query.lt("updated_at", cutoff);
    } else if (filter === "no_photo") {
      query = query.or("avatar_url.is.null,avatar_url.eq.");
    } else if (filter === "city" && city) {
      query = query.ilike("location", `%${city}%`);
    }

    const { data: recipients, error: qErr } = await query.limit(1000);
    if (qErr) return errorResponse("Query failed: " + qErr.message, 500);
    if (!recipients?.length) return successResponse({ sent: 0, failed: 0, message: "No matching users with FCM tokens" });

    // 4. Log notification row first (get the ID for open tracking)
    const { data: notifRow, error: insertErr } = await supabase
      .from("push_notifications")
      .insert({
        title, body, image_url: imageUrl || null,
        filter_type: filter, filter_city: city || null,
        sent_count: 0, open_count: 0, fail_count: 0,
        created_by: user.id,
      })
      .select("id").single();
    if (insertErr) return errorResponse("Failed to log notification: " + insertErr.message, 500);

    const notificationId = notifRow.id;

    // 5. Get FCM service account
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) throw new Error("FIREBASE_SERVICE_ACCOUNT not set");
    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;
    const accessToken = await getAccessToken(serviceAccount);

    // 6. Send in parallel batches of 50
    const tokens = recipients.map(r => r.fcm_token as string);
    const data = { notification_id: notificationId, type: "admin_broadcast" };
    let sent = 0, failed = 0;

    for (let i = 0; i < tokens.length; i += 50) {
      const batch = tokens.slice(i, i + 50);
      const results = await Promise.allSettled(
        batch.map(t => sendOne(t, title, body, data, accessToken, projectId))
      );
      results.forEach(r => { r.status === "fulfilled" && r.value ? sent++ : failed++; });
    }

    // 7. Update counts on the log row
    await supabase.from("push_notifications")
      .update({ sent_count: sent, fail_count: failed })
      .eq("id", notificationId);

    console.log(`📢 Admin broadcast by ${user.id}: ${sent} sent, ${failed} failed`);
    return successResponse({ notificationId, sent, failed, total: tokens.length });

  } catch (err) {
    if (err instanceof Response) return err;
    console.error("❌ send-bulk-notification error:", err);
    return errorResponse(String(err), 500);
  }
});
