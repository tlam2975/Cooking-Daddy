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

After deploying, open `https://YOUR-PROJECT.vercel.app/health` and expect a
JSON response with `"status": "ok"`. Then call `/api/quota` and test recipe
generation with a configured Gemini key. Build the Flutter app with
`--dart-define=API_BASE_URL=https://YOUR-PROJECT.vercel.app` (no trailing slash).

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

The quota counter and weather/nutrition caches currently live in process
memory. Vercel can start multiple instances and recycle them, so `/api/quota`
is only an instance-local estimate and does not enforce a global daily limit.
Add durable, shared quota storage and request authentication before relying on
this endpoint to control public AI usage. YouTube may also block transcript
requests from cloud IP addresses, independently of a successful deployment.

For local checks from this directory:

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest discover -p 'test_*.py'
```

Vercel CLI version 48.2.10 or newer can run `vercel dev` from this directory
to exercise the deployed routing locally.
