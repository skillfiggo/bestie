# Agora Token Server

Production-ready Node.js microservice for generating Agora RTC tokens.

## 🚀 Why This Exists

Supabase Edge Functions (Deno) **cannot** run `crypto.createHmac`, which is required by Agora's token generation. This Node.js server solves that limitation.

## 📦 Setup

### 1. Install Dependencies

```bash
cd agora-token-server
npm install
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` and add your Agora credentials:

```env
AGORA_APP_ID=your_actual_app_id
AGORA_APP_CERTIFICATE=your_actual_certificate
PORT=3000
```

### 3. Run Locally

```bash
npm run dev
```

Server will start on `http://localhost:3000`

## 🧪 Test Locally

```bash
curl -X POST http://localhost:3000/agora/token \
  -H "Content-Type: application/json" \
  -d '{"channelName": "test-channel", "uid": 0}'
```

## 🌐 Deploy to Railway

### Option 1: Railway CLI

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Deploy
railway up
```

### Option 2: Railway Dashboard

1. Go to [railway.app](https://railway.app)
2. Click "New Project" → "Deploy from GitHub repo"
3. Select this repository
4. Set root directory to `agora-token-server`
5. Add environment variables in Railway dashboard:
   - `AGORA_APP_ID`
   - `AGORA_APP_CERTIFICATE`
6. Deploy!

Railway will automatically detect `package.json` and run `npm start`.

## 🔐 Security (IMPORTANT)

### Current State
The endpoint is **publicly accessible**. Anyone with the URL can generate tokens.

### Recommended: Add Supabase JWT Verification

Uncomment the JWT verification code in `index.js`:

```javascript
// Verify Supabase JWT
const authHeader = req.headers.authorization;
if (!authHeader) {
  return res.status(401).json({ error: "Missing authorization header" });
}

// Verify the JWT with Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

const { data: { user }, error } = await supabase.auth.getUser(
  authHeader.replace('Bearer ', '')
);

if (error || !user) {
  return res.status(401).json({ error: "Unauthorized" });
}
```

Then install Supabase client:

```bash
npm install @supabase/supabase-js
```

## 📱 Flutter Integration

Update your Flutter code to call this server instead of Supabase Edge Function:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> getAgoraToken(String channelName) async {
  final url = Uri.parse('https://your-railway-app.up.railway.app/agora/token');
  
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'channelName': channelName,
      'uid': 0,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['token'];
  } else {
    throw Exception('Failed to get Agora token');
  }
}
```

## 🔍 Endpoints

### `GET /health`
Health check endpoint

**Response:**
```json
{
  "status": "ok",
  "service": "agora-token-server"
}
```

### `POST /agora/token`
Generate Agora RTC token

**Request Body:**
```json
{
  "channelName": "my-channel",
  "uid": 0,
  "role": "publisher"
}
```

**Response:**
```json
{
  "token": "006abc123...",
  "appId": "your-app-id",
  "channelName": "my-channel",
  "uid": 0,
  "expiresAt": 1735567890
}
```

## 📊 Monitoring

After deployment, monitor logs:

```bash
railway logs
```

## 🛠️ Alternative Deployment Options

- **Render**: Similar to Railway, auto-detects Node.js
- **Fly.io**: Good for global edge deployment
- **Vercel**: Works but use Serverless Functions (not Edge)
- **Google Cloud Run**: Container-based deployment

## ✅ Production Checklist

- [ ] Environment variables set in Railway
- [ ] JWT verification enabled (recommended)
- [ ] HTTPS enabled (automatic on Railway)
- [ ] Monitoring/logging configured
- [ ] Rate limiting added (optional)
- [ ] CORS configured for your Flutter app domain

## 🐛 Troubleshooting

### "Server configuration error"
- Check that `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` are set in Railway environment variables

### "Missing channelName"
- Ensure your Flutter app sends `channelName` in the request body

### Token still invalid in Agora
- Verify your Agora App ID matches
- Check token hasn't expired
- Ensure channel name matches exactly
