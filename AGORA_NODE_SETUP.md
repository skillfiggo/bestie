# 🚀 Agora Token Server Setup Guide

## ✅ What We Built

A **production-ready Node.js microservice** for Agora token generation that solves the Supabase Edge Function limitation.

### Why This Solution?

❌ **Supabase Edge Functions (Deno)** cannot run `crypto.createHmac`  
✅ **Node.js** has full crypto support and works perfectly with Agora

---

## 📋 Quick Start

### 1️⃣ Install Dependencies

```bash
cd agora-token-server
npm install
```

### 2️⃣ Configure Environment Variables

Create a `.env` file in the `agora-token-server` directory:

```bash
# Copy the example file
cp .env.example .env
```

Edit `.env` and add your **actual Agora credentials**:

```env
AGORA_APP_ID=your_actual_agora_app_id
AGORA_APP_CERTIFICATE=your_actual_agora_certificate
PORT=3000
```

> 🔑 Find your credentials in the [Agora Console](https://console.agora.io/)

### 3️⃣ Test Locally

```bash
npm start
```

You should see:

```
🚀 Agora token server running on port 3000
📡 Health check: http://localhost:3000/health
🔑 Token endpoint: POST http://localhost:3000/agora/token
```

### 4️⃣ Test the Endpoint

Open a new terminal and run:

```bash
curl -X POST http://localhost:3000/agora/token -H "Content-Type: application/json" -d "{\"channelName\": \"test-channel\"}"
```

You should get a response like:

```json
{
  "token": "006abc123def456...",
  "appId": "your-app-id",
  "channelName": "test-channel",
  "uid": 0,
  "expiresAt": 1735567890
}
```

✅ If you see this, your server is working!

---

## 🌐 Deploy to Railway (Recommended)

### Option A: Railway Dashboard (Easiest)

1. **Sign up** at [railway.app](https://railway.app)
2. Click **"New Project"** → **"Deploy from GitHub repo"**
3. Connect your GitHub account and select this repository
4. Set **Root Directory** to `agora-token-server`
5. Add **Environment Variables**:
   - `AGORA_APP_ID` = your app ID
   - `AGORA_APP_CERTIFICATE` = your certificate
6. Click **Deploy**

Railway will:
- Auto-detect `package.json`
- Run `npm install`
- Start the server with `npm start`
- Give you a public URL like: `https://agora-token-production.up.railway.app`

### Option B: Railway CLI

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Navigate to the token server directory
cd agora-token-server

# Initialize and deploy
railway init
railway up
```

### 🔧 Set Environment Variables in Railway

After deployment:

```bash
railway variables set AGORA_APP_ID=your_app_id
railway variables set AGORA_APP_CERTIFICATE=your_certificate
```

Or use the Railway dashboard → Your Project → Variables

---

## 📱 Update Flutter App

### Update the Token Server URL

Edit `lib/features/calling/data/repositories/agora_token_repository.dart`:

```dart
// Replace this line:
static const String _tokenServerUrl = 'http://localhost:3000/agora/token';

// With your Railway URL:
static const String _tokenServerUrl = 'https://your-app.up.railway.app/agora/token';
```

### Verify `http` Package

Make sure `pubspec.yaml` includes:

```yaml
dependencies:
  http: ^1.1.0
```

If not, run:

```bash
flutter pub add http
```

---

## 🔐 Security (IMPORTANT)

### Current State: Public Access ⚠️

Right now, **anyone** with your server URL can generate tokens.

### Recommended: Add JWT Verification

1. **Install Supabase client** in the token server:

```bash
cd agora-token-server
npm install @supabase/supabase-js
```

2. **Update `index.js`** to verify Supabase JWT:

```javascript
import { createClient } from '@supabase/supabase-js';

// Add after imports
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

// In the /agora/token endpoint, add before token generation:
const authHeader = req.headers.authorization;
if (!authHeader) {
  return res.status(401).json({ error: "Missing authorization header" });
}

const { data: { user }, error } = await supabase.auth.getUser(
  authHeader.replace('Bearer ', '')
);

if (error || !user) {
  return res.status(401).json({ error: "Unauthorized" });
}

console.log(`Authenticated user: ${user.id}`);
```

3. **Add environment variables** in Railway:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. **Update Flutter** to send JWT:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<AgoraTokenResponse> getToken({
  required String channelName,
  int? uid,
  int? role,
}) async {
  final session = Supabase.instance.client.auth.currentSession;
  final token = session?.accessToken;

  final response = await http.post(
    Uri.parse(_tokenServerUrl),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'channelName': channelName,
      if (uid != null) 'uid': uid,
      if (role != null) 'role': role,
    }),
  );
  // ... rest of the code
}
```

---

## 🧪 Testing Checklist

After deployment, verify:

- [ ] Server health check works: `GET https://your-app.up.railway.app/health`
- [ ] Token generation works: `POST https://your-app.up.railway.app/agora/token`
- [ ] Flutter app can fetch tokens
- [ ] Agora calls connect successfully
- [ ] No more `errInvalidToken` errors
- [ ] `onJoinChannelSuccess` fires
- [ ] Remote video appears

---

## 🐛 Troubleshooting

### "Server configuration error"
**Cause:** Missing Agora credentials  
**Fix:** Set `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` in Railway environment variables

### "Missing channelName"
**Cause:** Flutter app not sending `channelName`  
**Fix:** Check your Flutter code is sending the correct body

### Token still invalid in Agora
**Cause:** Mismatched App ID or expired token  
**Fix:** 
- Verify App ID matches in Agora Console
- Check token hasn't expired (1 hour default)
- Ensure channel name matches exactly

### Connection refused (localhost)
**Cause:** Server not running  
**Fix:** Run `npm start` in the `agora-token-server` directory

### CORS errors in Flutter
**Cause:** CORS not configured  
**Fix:** The server already has CORS enabled. If issues persist, check your Flutter app's network permissions.

---

## 📊 Monitoring

### View Logs in Railway

```bash
railway logs
```

Or use the Railway dashboard → Your Project → Deployments → View Logs

### What to Look For

✅ Good logs:
```
Generating token for channel: call_123
Token generated successfully, length: 256
```

❌ Bad logs:
```
Missing Agora credentials in environment
Error generating token: ...
```

---

## 🎯 Alternative Deployment Options

| Platform | Pros | Cons |
|----------|------|------|
| **Railway** | Easiest, auto-deploy, great DX | Paid after trial |
| **Render** | Free tier, similar to Railway | Slower cold starts |
| **Fly.io** | Global edge deployment | More complex setup |
| **Vercel** | Serverless, auto-scaling | Must use Serverless (not Edge) |
| **Google Cloud Run** | Scalable, container-based | Requires Docker knowledge |

---

## ✅ Production Checklist

Before going live:

- [ ] Environment variables set in production
- [ ] JWT verification enabled (recommended)
- [ ] HTTPS enabled (automatic on Railway)
- [ ] Monitoring/logging configured
- [ ] Rate limiting added (optional but recommended)
- [ ] CORS configured for your domain
- [ ] Error handling tested
- [ ] Token expiration tested

---

## 📚 Additional Resources

- [Agora Token Documentation](https://docs.agora.io/en/video-calling/develop/authentication-workflow)
- [Railway Documentation](https://docs.railway.app/)
- [Node.js Agora Token Builder](https://www.npmjs.com/package/agora-access-token)

---

## 🆘 Need Help?

If you encounter issues:

1. Check the server logs in Railway
2. Test the endpoint with `curl` or Postman
3. Verify environment variables are set correctly
4. Check Agora Console for App ID and Certificate
5. Ensure Flutter app is sending correct request format

---

## 🎉 Success Criteria

You'll know it's working when:

✅ Server deploys successfully to Railway  
✅ Health check returns `{"status": "ok"}`  
✅ Token endpoint returns a valid token  
✅ Flutter app receives the token  
✅ Agora call connects without errors  
✅ Both users can see/hear each other  
✅ No `errInvalidToken` in logs  

**You've successfully moved from broken Edge Functions to production-ready Node.js! 🚀**
