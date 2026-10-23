from flask import Flask, g, request, jsonify, render_template, send_from_directory
from flask_cors import CORS
import os
import json
import secrets
from dotenv import load_dotenv
from datetime import datetime
from gemini_service import GeminiService, GeminiConfigurationError, GeminiRequestError
from recipe_schema import RecipeOutput
from models import SmartGenerateRequest
from prompts import (
    build_remix_prompt,
    build_prompt,
    build_smart_prompt,
    build_prompt_from_URL,
)
from youtube_service import get_youtube_transcript, canonical_youtube_url, youtube_thumbnail
from service import SmartRecipeService
from nutrition_service import NutritionLookupUnavailable, NutritionService
from dashboard_service import DashboardService
from remix_service import valid_recipe
from vercel_logs import LogProviderError, read_runtime_logs
from api_auth import protect_api
from quota_service import FirestoreQuotaStore, QuotaExceeded, QuotaUnavailable

# Load env
load_dotenv()

global sampleRecipe

sampleRecipe = {
    "context": {
        "hour": 16,
        "meal_time": "snacks",
        "weather": {
            "city": "Hanoi",
            "condition": "Clouds",
            "description": "scattered clouds",
            "feels_like": 35.04,
            "humidity": 70,
            "is_raining": False,
            "temperature": 30
        }
    },
    "recipe": {
        "ingredients": [
            {"name": "beef sirloin", "quantity": 250, "unit": "g"},
            {"name": "asparagus", "quantity": 200, "unit": "g"},
            {"name": "unsalted butter", "quantity": 40, "unit": "g"},
            {"name": "potato", "quantity": 400, "unit": "g"},
            {"name": "salt", "quantity": None, "unit": None},
            {"name": "black pepper", "quantity": None, "unit": None},
            {"name": "vegetable oil", "quantity": 20, "unit": "ml"},
            {"name": "garlic cloves", "quantity": 2, "unit": "pcs"}
        ],
        "name": "Pan-Seared Beef with Garlicky Asparagus and Crispy Potatoes",
        "category": "dinner",
        "tags": ["high-protein", "comfort", "dinner"],
        "steps": [
            {
                "activityType": "chop",
                "instruction": "Wash and peel the potatoes, then slice them into 0.5 cm thick rounds or small cubes.",
                "whatToLookFor": "Evenly cut potato pieces for uniform cooking."
            },
            {
                "activityType": "heat",
                "heat": "medium",
                "instruction": "Heat vegetable oil in a pan over medium heat. Add the sliced potatoes, season with salt and black pepper. Cook, stirring occasionally.",
                "seasoning": "salt, black pepper",
                "time": 1000,
                "whatToLookFor": "Potatoes are fork-tender and golden brown on all sides."
            },
            {
                "activityType": "chop",
                "instruction": "While potatoes are cooking, wash the asparagus and snap off the woody ends (they naturally break where the tender part begins). Pat the beef dry with paper towels. Season generously with salt and black pepper on all sides. Mince the 2 garlic cloves.",
                "whatToLookFor": "Asparagus is trimmed to only the tender green spears. Beef is dry and fully seasoned."
            },
            {
                "activityType": "heat",
                "heat": "medium",
                "instruction": "Once potatoes are cooked, remove them from the pan and keep warm. Add 10g of butter to the same pan over medium heat. Once melted, add the asparagus and minced garlic.",
                "seasoning": "salt, black pepper",
                "time": 300,
                "whatToLookFor": "Asparagus is bright green and tender-crisp, with a fragrant garlic aroma."
            },
            {
                "activityType": "heat",
                "heat": "medium-high",
                "instruction": "Remove the asparagus from the pan and set aside with the potatoes. Add the remaining 30g of butter to the pan and increase heat to medium-high. Once butter is sizzling and lightly browned, carefully place the seasoned beef in the pan.",
                "time": 420,
                "whatToLookFor": "A deep brown crust forms on the beef. Cook to your desired doneness (e.g., 3-4 minutes per side for medium-rare)."
            },
            {
                "activityType": "wait",
                "instruction": "Remove beef from the pan and let it rest on a cutting board for 5-10 minutes before slicing. This helps keep the juices in. Slice the beef against the grain and serve immediately with the pan-fried potatoes and asparagus.",
                "time": 400,
                "whatToLookFor": "Beef is juicy and tender after resting, and easy to slice."
            }
        ],
        "tools": [
            {"name": "pan", "quantity": 1},
            {"name": "knife", "quantity": 1},
            {"name": "cutting board", "quantity": 1},
            {"name": "tongs", "quantity": 1},
            {"name": "spatula", "quantity": 1}
        ]
    },
    "success": True
}

API_KEYS = [
    os.getenv('GEMINI_API_KEY_1'),
    os.getenv('GEMINI_API_KEY_2'),
    os.getenv('GEMINI_API_KEY_3'),
    # os.getenv('GEMINI_API_KEY_4'),
]
API_KEYS = [k for k in API_KEYS if k]
if not API_KEYS:
    API_KEYS = [key for key in [os.getenv('GEMINI_API_KEY') or os.getenv('GOOGLE_API_KEY')] if key]
DAILY_LIMIT = max(1, int(os.getenv('DAILY_REQUEST_LIMIT', '30')))
quota_store = FirestoreQuotaStore()

gemini_service = GeminiService(API_KEYS)
smart_service = SmartRecipeService(os.getenv('WEATHER_API_KEY'))
nutrition_service = NutritionService()
dashboard_service = DashboardService()

app = Flask(__name__)
CORS(app)
protect_api(app)



# ==================== UTIL ====================

def clean_json_response(text):
    text = text.strip()
    if text.startswith('```json'):
        text = text[7:]
    elif text.startswith('```'):
        text = text[3:]
    if text.endswith('```'):
        text = text[:-3]
    return text.strip()


def is_gemini_error(parsed):
    """True if Gemini returned {"error": "..."} instead of an actual recipe."""
    return isinstance(parsed, dict) and 'error' in parsed and 'steps' not in parsed


def generate_recipe_response(prompt, context=None, source_url=None):
    """All generation uses one schema and one durable account entitlement."""
    if not gemini_service.clients:
        return jsonify(success=False, error='Recipe generation is unavailable',
                       error_code='ai_not_configured'), 503
    reservation = None
    committed = False
    try:
        reservation, remaining = quota_store.reserve(g.user_id, DAILY_LIMIT)
        text = gemini_service.generate(prompt, response_schema=RecipeOutput.model_json_schema())
        recipe = RecipeOutput.model_validate_json(clean_json_response(text)).model_dump()
        reason = (recipe.pop('error', None) or '').strip()
        if reason:
            # Not committed, so the reservation is released below.
            app.logger.info('Gemini found no recipe: %s', reason[:200])
            return jsonify(success=False, error='No recipe found in this source',
                           error_code='ai_not_a_recipe'), 422
        if source_url:
            recipe['url'] = source_url
            recipe['imageUrl'] = youtube_thumbnail(source_url)
        committed = True
        payload = {'success': True, 'recipe': recipe, 'remaining_quota': remaining}
        if context is not None:
            payload['context'] = context
        return jsonify(payload)
    except QuotaExceeded:
        return jsonify(success=False, error='Daily quota exceeded', error_code='ai_quota_error'), 429
    except QuotaUnavailable:
        return jsonify(success=False, error='Quota is temporarily unavailable', error_code='ai_quota_unavailable'), 503
    except GeminiConfigurationError:
        return jsonify(success=False, error='Recipe generation is unavailable', error_code='ai_not_configured'), 503
    except ValueError:
        return jsonify(success=False, error='AI returned an invalid recipe', error_code='ai_invalid_recipe'), 422
    except GeminiRequestError as error:
        code = 'ai_quota_error' if error.status_code == 429 else 'ai_generation_error'
        return jsonify(success=False, error='Recipe generation is unavailable', error_code=code), (429 if error.status_code == 429 else 503)
    except Exception:
        app.logger.exception('Recipe generation failed')
        return jsonify(success=False, error='Recipe generation is unavailable', error_code='ai_generation_error'), 503
    finally:
        if reservation is not None and not committed:
            try:
                quota_store.release(g.user_id, reservation)
            except QuotaUnavailable:
                app.logger.error('Could not release failed generation reservation')


# ==================== ROUTES ====================
@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')


@app.route('/docs', methods=['GET'])
def docs():
    return render_template('docs.html', logs_enabled=bool(os.getenv('LOG_VIEWER_PASSWORD')))


@app.route('/logo.png', methods=['GET'])
def logo():
    # Vercel serves public/ through its CDN; this also supports local Flask runs.
    return send_from_directory(os.path.join(app.root_path, 'public'), 'logo.png')


@app.route('/favicon.png', methods=['GET'])
def favicon():
    return send_from_directory(os.path.join(app.root_path, 'public'), 'favicon.png')


def _authorize_log_viewer():
    expected_password = os.getenv('LOG_VIEWER_PASSWORD')
    if not expected_password:
        return jsonify(error='Log viewer is not configured'), 404
    credentials = request.authorization
    if (not credentials or credentials.type != 'basic' or
            # compare_digest raises TypeError on non-ASCII str, so compare bytes.
            not secrets.compare_digest((credentials.username or '').encode('utf-8'), b'admin') or
            not secrets.compare_digest((credentials.password or '').encode('utf-8'),
                                       expected_password.encode('utf-8'))):
        response = jsonify(error='Authentication required')
        response.status_code = 401
        response.headers['WWW-Authenticate'] = 'Basic realm="Cooking Daddy logs"'
        response.headers['Cache-Control'] = 'no-store'
        return response
    return None


@app.route('/admin/logs', methods=['GET'])
def log_viewer():
    denied = _authorize_log_viewer()
    if denied is not None:
        return denied
    response = app.make_response(render_template('logs.html'))
    response.headers['Cache-Control'] = 'no-store'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['Content-Security-Policy'] = ("default-src 'self'; style-src 'self' 'unsafe-inline'; "
                                                   "script-src 'self' 'unsafe-inline'; frame-ancestors 'none'")
    response.headers['Referrer-Policy'] = 'no-referrer'
    return response


@app.route('/admin/logs/data', methods=['GET'])
def log_viewer_data():
    denied = _authorize_log_viewer()
    if denied is not None:
        return denied
    token = os.getenv('VERCEL_API_TOKEN')
    project_id = os.getenv('VERCEL_PROJECT_ID')
    deployment_id = os.getenv('VERCEL_DEPLOYMENT_ID')
    if not all((token, project_id, deployment_id)):
        response = jsonify(error='Set VERCEL_API_TOKEN and expose Vercel system environment variables.')
        response.status_code = 503
    else:
        try:
            rows = read_runtime_logs(token, project_id, deployment_id,
                                     os.getenv('VERCEL_TEAM_ID'))
            response = jsonify(logs=rows)
        except LogProviderError as error:
            response = jsonify(error=str(error))
            response.status_code = 502
    response.headers['Cache-Control'] = 'no-store'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    return response


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'ai_ready': bool(gemini_service.clients),
                    'timestamp': datetime.utcnow().isoformat() + 'Z'})

@app.route('/ready', methods=['GET'])
def ready():
    available = bool(gemini_service.clients)
    return jsonify(ai_ready=available), (200 if available else 503)

@app.route('/api/quota', methods=['GET'])
def get_quota():
    try:
        result = quota_store.snapshot(g.user_id, DAILY_LIMIT)
        if not gemini_service.clients:
            result['remaining'] = 0
        result['ai_ready'] = bool(gemini_service.clients)
        return jsonify(result)
    except QuotaUnavailable:
        return jsonify(success=False, error_code='ai_quota_unavailable'), 503

@app.route('/api/dashboard', methods=['GET'])
def dashboard():
    day = request.args.get('date')
    lang = request.args.get('lang')
    return jsonify(dashboard_service.get_daily_brief(day, lang))

@app.route('/api/generate-from-ingredients', methods=['POST'])
def generate():
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or not isinstance(data.get('ingredients'), str) or not data['ingredients'].strip():
        return jsonify(success=False, error='Ingredients are required'), 400
    prompt = build_prompt(ingredients=data['ingredients'], tools=data.get('tools'),
        session_length=data.get('sessionLength', 'short'), difficulty=data.get('difficulty', 'normal'),
        dish=data.get('dish'))
    return generate_recipe_response(prompt)


@app.route('/api/smart-generate', methods=['POST'])
def smart_generate():
    try:
        req = SmartGenerateRequest(request.get_json(silent=True))
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

    # Check quota before the weather lookups so an exhausted account costs nothing.
    try:
        if quota_store.snapshot(g.user_id, DAILY_LIMIT)['remaining'] <= 0:
            return jsonify(success=False, error='Daily quota exceeded', error_code='ai_quota_error'), 429
    except QuotaUnavailable:
        return jsonify(success=False, error='Quota is temporarily unavailable', error_code='ai_quota_unavailable'), 503

    context = smart_service.build_context(req)

    prompt = build_smart_prompt(
        req.ingredients,
        req.tools,
        req.dish,
        req.session_length,
        req.difficulty,
        context["weather"],
        context["meal_time"],
        context["hour"],
        req.language,
        context["city"],

    )

    return generate_recipe_response(prompt, context)
    
@app.route('/api/generate-from-url', methods=['POST'])
def generate_from_url():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify(success=False, error_code='youtube_invalid_url'), 400
    try:
        url = canonical_youtube_url(data.get('url'))
    except ValueError:
        return jsonify(success=False, error='Use a supported YouTube video URL', error_code='youtube_invalid_url'), 400
    if not gemini_service.clients:
        return jsonify(success=False, error_code='ai_not_configured'), 503
    try:
        if quota_store.snapshot(g.user_id, DAILY_LIMIT)['remaining'] <= 0:
            return jsonify(success=False, error_code='ai_quota_error'), 429
    except QuotaUnavailable:
        return jsonify(success=False, error_code='ai_quota_unavailable'), 503
    try:
        transcript = get_youtube_transcript(url)
    except Exception as error:
        # Provider diagnostics belong in server logs, not mobile error copy.
        app.logger.warning('YouTube transcript import unavailable: %s: %s',
                           type(error).__name__, str(error)[:300], exc_info=True)
        return jsonify(success=False, error='Captions are unavailable. Try another video or enter ingredients manually.',
                       error_code='youtube_import_unavailable'), 503
    return generate_recipe_response(build_prompt_from_URL(transcript), source_url=url)

@app.route('/api/debug/sample-recipe', methods=['GET'])
def get_sample_recipe():
    return jsonify(sampleRecipe)

@app.route('/api/remix', methods=['POST'])
def remix_recipe():
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or not valid_recipe(data.get('recipe')):
        return jsonify(success=False, error='A complete source recipe is required'), 400
    instructions = data.get('instructions', '')
    language = data.get('language', 'en')
    portions = data['recipe'].get('basePortions', 1)
    if not isinstance(instructions, str) or len(instructions) > 1000:
        return jsonify(success=False, error='Instructions must be at most 1000 characters'), 400
    if language not in ('en', 'vi') or type(portions) is not int or portions < 1:
        return jsonify(success=False, error='Invalid language or portion count'), 400
    prompt = build_remix_prompt(data['recipe'], instructions.strip(), language)
    return generate_recipe_response(prompt)


@app.route('/api/energy-note', methods=['POST'])
def energy_note():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify(success=False, error='Invalid recipe'), 400
    try:
        return jsonify(success=True, **nutrition_service.build_note(data))
    except NutritionLookupUnavailable:
        return jsonify(success=False, error='Nutrition lookup is unavailable'), 503

# ==================== RUN ====================

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=2975, debug=True)
