# 🎯 Next Steps - Agora Token Server

## ✅ What's Done

- ✅ Created Node.js token server in `agora-token-server/`
- ✅ Updated Flutter app to use HTTP instead of Supabase Edge Function
- ✅ Installed npm dependencies

---

## 🔧 What You Need to Do Now

### 1️⃣ Add Your Agora Credentials (REQUIRED)

Create `.env` file in `agora-token-server/` directory:

```env
AGORA_APP_ID=your_actual_app_id_here
AGORA_APP_CERTIFICATE=your_actual_certificate_here
PORT=3000
```

> 🔑 Get these from [Agora Console](https://console.agora.io/) → Your Project → Basic Info

---

### 2️⃣ Test Locally

```bash
cd agora-token-server
npm start
```

Expected output:
```
🚀 Agora token server running on port 3000
📡 Health check: http://localhost:3000/health
🔑 Token endpoint: POST http://localhost:3000/agora/token
```

Test it:
```bash
curl -X POST http://localhost:3000/agora/token -H "Content-Type: application/json" -d "{\"channelName\": \"test\"}"
```

---

### 3️⃣ Deploy to Railway

**Option A: Railway Dashboard (Easiest)**

1. Go to [railway.app](https://railway.app) and sign up
2. Click "New Project" → "Deploy from GitHub repo"
3. Connect GitHub and select your repository
4. Set **Root Directory** to `agora-token-server`
5. Add environment variables:
   - `AGORA_APP_ID`
   - `AGORA_APP_CERTIFICATE`
6. Deploy!

**Option B: Railway CLI**

```bash
npm i -g @railway/cli
railway login
cd agora-token-server
railway init
railway up
```

---

### 4️⃣ Update Flutter App with Production URL

After Railway deployment, you'll get a URL like:
```
https://agora-token-production.up.railway.app
```

Update `lib/features/calling/data/repositories/agora_token_repository.dart`:

```dart
// Change this line (around line 11):
static const String _tokenServerUrl = 'http://localhost:3000/agora/token';

// To your Railway URL:
static const String _tokenServerUrl = 'https://your-app.up.railway.app/agora/token';
```

---

### 5️⃣ Test Video Calls

1. Run your Flutter app
2. Initiate a video call
3. Check logs for:
   - ✅ `🔑 Token received successfully`
   - ✅ `onJoinChannelSuccess`
   - ✅ Remote video appears

---

## 🔐 Optional: Add Security (Recommended)

Add JWT verification to prevent unauthorized token generation.

See `AGORA_NODE_SETUP.md` → Security section for detailed instructions.

---

## 📚 Documentation

- **Full Setup Guide**: `AGORA_NODE_SETUP.md`
- **Token Server README**: `agora-token-server/README.md`

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Server configuration error" | Add `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` to `.env` |
| Connection refused | Make sure server is running (`npm start`) |
| Token still invalid | Verify App ID matches in Agora Console |
| CORS errors | Already configured, check Flutter network permissions |

---

## 🎉 Success Criteria

You'll know it works when:

✅ Local server starts without errors  
✅ Token endpoint returns a valid token  
✅ Railway deployment succeeds  
✅ Flutter app connects to Agora  
✅ Video calls work without `errInvalidToken`  

---

## 📞 Quick Commands

```bash
# Install dependencies
cd agora-token-server && npm install

# Run locally
npm start

# Deploy to Railway
railway up

# View Railway logs
railway logs
```

---

**Ready to go! Start with step 1️⃣ above. 🚀**
