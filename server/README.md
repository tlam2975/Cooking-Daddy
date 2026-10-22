# Deploy the Cooking Daddy API to Vercel

Create a Vercel project from this repository and set **Root Directory** to
`server`. Select the **Flask** framework preset if Vercel does not detect it.
Keep the install and build commands at their defaults. Vercel detects the
`app` object in `main.py`; `vercel.json` allows up to 60 seconds for API calls.
The tracked `.python-version` selects Python 3.12.

In Vercel Project Settings > Environment Variables, set `GEMINI_API_KEY` or
one or more of `GEMINI_API_KEY_1`, `GEMINI_API_KEY_2`, and `GEMINI_API_KEY_3`.
If numbered keys are present, the single key is ignored. Set `OFF_USER_AGENT`
to `CookingDaddy/2.0 (your contact URL or email)` for Open Food Facts requests.
`WEATHER_API_KEY` is optional; it is used only if Open-Meteo fails. Set the
variables for each Vercel environment you deploy to. Never upload `.env` or
put real keys in the Flutter app.

After deploying, open `https://cooking-daddy.vercel.app/health` and expect a
JSON response with `"status": "ok"`. `/health` also returns `ai_ready`;
`/ready` returns 503 when Gemini credentials or its SDK are missing. Check
`/ready` before enabling generation. Then call `/api/quota` and test recipe
generation with a configured Gemini key. The Flutter app defaults to
`https://cooking-daddy.vercel.app`; override it at build time with
`--dart-define=API_BASE_URL=https://YOUR-PROJECT.vercel.app` if the host changes
(no trailing slash).

## API authentication

Every `/api/` route requires `Authorization: Bearer <Firebase ID token>`.
Flutter obtains this token from the existing signed-in Firebase user and
refreshes it once if the server returns 401. Missing, expired, invalid, revoked,
disabled-user, and anonymous-user credentials are rejected before route work.
The home page, `/docs`, `/health`, and CORS preflight remain public. The runtime
log viewer continues to use its separate operator password.

Before deploying this version:

1. In Firebase **Project settings > Service accounts**, generate an Admin SDK
   service-account key for `cooking-daddy-83353`.
2. In Vercel **Project Settings > Environment Variables**, add
   `FIREBASE_SERVICE_ACCOUNT_JSON` with the complete JSON key as its value. Set
   it for each environment being deployed. Keep it on the server; never commit
   it or include it in a Flutter build.
3. Redeploy the backend and rebuild/reinstall the Flutter app together. Older
   builds that do not send ID tokens will receive 401 for API calls.

The expected Firebase project defaults to `cooking-daddy-83353`. Only set
`FIREBASE_PROJECT_ID` when intentionally changing the Firebase project on both
client and server. Locally, either set `FIREBASE_SERVICE_ACCOUNT_JSON` in
`server/.env` or set `GOOGLE_APPLICATION_CREDENTIALS` to the path of a key stored
outside the repository. The service account needs permission to read Firebase
Auth users and read/write the Firestore `api_quotas` collection. Mobile clients
remain unable to write that collection under the existing rules. See the
[Firebase Admin setup guide](https://firebase.google.com/docs/admin/setup).

If credentials or Firebase verification are unavailable, authenticated requests
receive 503 with `error_code: auth_unavailable`; the API never falls back to
public access. `/health` reports process health, not Firebase readiness.

After deployment, verify that `/health` returns 200, an unauthenticated
`/api/quota` returns 401, and quota and generation work from a signed-in rebuilt
app. Tokens and credential contents are not written to application logs.

Authentication restricts access to signed-in accounts. Successful generation
and active reservations count toward the daily per-account allowance. It does
not prove a request comes from the official app.

## Runtime logs

The `/` page is the developer home, and `/docs` lists the available endpoints.
To enable the private runtime log
viewer at `/admin/logs`, set `LOG_VIEWER_PASSWORD` to a long random value and
`VERCEL_API_TOKEN` to a Vercel access token allowed to read this project. Log in
with HTTP Basic username `admin` and that password. The token stays on the
server and is never included in the page or API response. In Vercel settings,
turn on **Automatically expose System Environment Variables** so
`VERCEL_PROJECT_ID` and `VERCEL_DEPLOYMENT_ID` are available at runtime. For a
team-owned project, also set `VERCEL_TEAM_ID`. The viewer reads a bounded sample
from Vercel's runtime log stream during each refresh. If these settings
are missing, log access stays disabled or reports the missing configuration.
Vercel's own Logs tab remains the source for full search and history.

Generation, remix, and YouTube import share a Firestore transaction counter
per Firebase UID and UTC date. `DAILY_REQUEST_LIMIT` defaults to 30 and controls
both enforcement and `/api/quota`. A claim reserves a slot before Gemini runs;
normal failures release it. An interrupted worker can leave a reserved slot
counted until the daily reset. Quota-store failures return 503 and prevent AI
work. Set a Firestore TTL policy on `api_quotas.expiresAt` to prune old counters.
See [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions).

Weather and nutrition caches remain process-local. Nutrition rejects queued
requests that cannot fit its 15-second work budget; clients close their owned
HTTP transport on timeout. This does not establish provider availability.

YouTube import accepts supported YouTube hosts, canonicalizes the video URL,
and builds thumbnails directly from its validated video ID. It never fetches
the supplied origin. YouTube can still block cloud IPs or withhold captions.
The app offers a short localized error and lets the user try another video or
enter ingredients manually. Open Food Facts outages remain provider errors;
no nutrition values are invented to mask them.

For local checks from this directory:

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest discover -p 'test_*.py'
```

Vercel CLI version 48.2.10 or newer can run `vercel dev` from this directory
to exercise the deployed routing locally.
