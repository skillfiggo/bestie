const express = require("express");
const cors = require("cors");
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");
const { createClient } = require("@supabase/supabase-js");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

// Initialize Supabase Client for JWT verification
const supabase = createClient(
    process.env.SUPABASE_URL || "",
    process.env.SUPABASE_ANON_KEY || ""
);

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get("/health", (req, res) => {
    res.json({
        status: "ok",
        service: "agora-token-server",
        timestamp: new Date().toISOString(),
        config: {
            has_app_id: !!process.env.AGORA_APP_ID,
            has_app_cert: !!process.env.AGORA_APP_CERTIFICATE,
            has_supabase_url: !!process.env.SUPABASE_URL,
            has_supabase_key: !!process.env.SUPABASE_ANON_KEY,
            port: PORT
        }
    });
});

// Agora token generation endpoint
app.post("/agora/token", async (req, res) => {
    try {
        // 1. Verify Authentication (JWT)
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            return res.status(401).json({ error: "Missing or invalid authorization header" });
        }

        const token_jwt = authHeader.split(" ")[1];
        const { data: { user }, error: authError } = await supabase.auth.getUser(token_jwt);

        if (authError || !user) {
            console.error("❌ Authentication failed:", authError?.message || "User not found");
            return res.status(401).json({ error: "Unauthorized: Invalid JWT" });
        }

        // 2. Parse and Validate Request
        const { channelName, uid, role } = req.body;

        if (!channelName) {
            return res.status(400).json({ error: "channelName is required" });
        }

        const AGORA_APP_ID = process.env.AGORA_APP_ID;
        const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE;

        if (!AGORA_APP_ID || !AGORA_APP_CERTIFICATE) {
            console.error("❌ Missing Agora configuration");
            return res.status(500).json({ error: "Server configuration error" });
        }

        // 3. Generate Token
        const uidNum = parseInt(uid) || 0;
        const roleNum = role === 2 || role === "audience" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
        const expirationTimeInSeconds = 3600; // 1 hour
        const currentTimestamp = Math.floor(Date.now() / 1000);
        const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

        // Logging parameters (Never log the token string itself)
        console.log(`[${new Date().toISOString()}] Generating Token:`, {
            userId: user.id,
            channel: channelName,
            uid: uidNum,
            role: roleNum === 1 ? 'Publisher' : 'Subscriber',
            expiry: new Date(privilegeExpiredTs * 1000).toLocaleString()
        });

        const token = RtcTokenBuilder.buildTokenWithUid(
            AGORA_APP_ID,
            AGORA_APP_CERTIFICATE,
            channelName,
            uidNum,
            roleNum,
            privilegeExpiredTs
        );

        console.log(`✅ Token generated for channel: ${channelName}`);

        res.json({
            token,
            appId: AGORA_APP_ID,
            channelName,
            uid: uidNum,
            expiresAt: privilegeExpiredTs,
        });
    } catch (error) {
        console.error("❌ Error in /agora/token:", error);
        res.status(500).json({
            error: error.message || "Internal server error",
        });
    }
});

// Start server
app.listen(PORT, HOST, () => {
    console.log(`🚀 Agora token server running at http://${HOST}:${PORT}`);
    console.log(`📡 Health check: http://${HOST}:${PORT}/health`);
    console.log(`🔑 Agora App ID loaded: ${!!process.env.AGORA_APP_ID}`);
    console.log(`🔑 Agora Cert loaded: ${!!process.env.AGORA_APP_CERTIFICATE}`);
    console.log(`🛡️ Supabase JWT Verification: ${!!process.env.SUPABASE_URL && !!process.env.SUPABASE_ANON_KEY ? 'ENABLED' : 'DISABLED'}`);
});
