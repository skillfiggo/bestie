import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  corsResponse,
  verifyAuth,
  errorResponse,
  successResponse,
} from '_shared/auth.ts'

// ─── Types ──────────────────────────────────────────────────────────────────

interface NotificationPayload {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

// ─── Google OAuth2 — Service Account JWT ────────────────────────────────────

async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
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
    "pkcs8",
    keyBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signatureBytes = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${signingInput}.${signature}`;

  // Exchange JWT for a short-lived OAuth2 access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

// ─── Main Handler ────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") return corsResponse()

  try {
    // ── 1. Authenticate the caller ────────────────────────────────────────
    // Only logged-in app users may trigger push notifications.
    // verifyAuth throws a 401 Response if the JWT is missing/invalid/expired.
    const { user } = await verifyAuth(req)

    // ── 2. Parse and validate request body ───────────────────────────────
    const { token, title, body, data }: NotificationPayload = await req.json();

    if (!token || !title || !body) {
      return errorResponse("Missing required fields: token, title, body", 400)
    }

    // Basic sanity checks to prevent notification content injection
    if (title.length > 100 || body.length > 500) {
      return errorResponse("title must be ≤100 chars, body must be ≤500 chars", 400)
    }

    // ── 3. Load Firebase service account ─────────────────────────────────
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT secret not set");
    }
    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;

    // ── 4. Get a short-lived OAuth2 access token ──────────────────────────
    const accessToken = await getAccessToken(serviceAccount);

    // ── 5. Build and send the FCM v1 message ─────────────────────────────
    const message = {
      message: {
        token,
        notification: { title, body },
        android: {
          priority: "HIGH",
          notification: {
            channelId: "bestie_notifications",
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
        data: data ?? {},
      },
    };

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const fcmResponse = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(message),
    });

    const fcmResult = await fcmResponse.json();

    if (!fcmResponse.ok) {
      console.error("FCM error:", JSON.stringify(fcmResult));
      return errorResponse(`FCM send failed: ${JSON.stringify(fcmResult)}`, 500)
    }

    console.log(`✅ Notification sent by user ${user.id}:`, fcmResult.name);
    return successResponse({ success: true, messageId: fcmResult.name })

  } catch (err) {
    // verifyAuth throws a Response directly — forward it
    if (err instanceof Response) return err

    console.error("❌ send-notification error:", err);
    return errorResponse(String(err), 500)
  }
});
