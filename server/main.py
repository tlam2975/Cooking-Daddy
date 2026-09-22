from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from dotenv import load_dotenv
from datetime import datetime
from gemini_service import GeminiService, GeminiConfigurationError, GeminiRequestError
from recipe_schema import RecipeOutput
from models import SmartGenerateRequest
from prompts import (
    build_energy_note_prompt,
    build_remix_prompt,
    build_prompt,
    build_smart_prompt,
    build_prompt_from_URL,
)
from youtube_service import get_youtube_transcript
from service import SmartRecipeService
from dashboard_service import DashboardService
from hero_image_service import find_hero_image
from remix_service import valid_recipe

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
                "instruction": "Wash and peel the potatoes, then slice them into 0.5 cm thick rounds or small cubes.",
                "whatToLookFor": "Evenly cut potato pieces for uniform cooking."
            },
            {
                "heat": "medium",
                "instruction": "Heat vegetable oil in a pan over medium heat. Add the sliced potatoes, season with salt and black pepper. Cook, stirring occasionally.",
                "seasoning": "salt, black pepper",
                "time": 1000,
                "whatToLookFor": "Potatoes are fork-tender and golden brown on all sides."
            },
            {
                "instruction": "While potatoes are cooking, wash the asparagus and snap off the woody ends (they naturally break where the tender part begins). Pat the beef dry with paper towels. Season generously with salt and black pepper on all sides. Mince the 2 garlic cloves.",
                "whatToLookFor": "Asparagus is trimmed to only the tender green spears. Beef is dry and fully seasoned."
            },
            {
                "heat": "medium",
                "instruction": "Once potatoes are cooked, remove them from the pan and keep warm. Add 10g of butter to the same pan over medium heat. Once melted, add the asparagus and minced garlic.",
                "seasoning": "salt, black pepper",
                "time": 300,
                "whatToLookFor": "Asparagus is bright green and tender-crisp, with a fragrant garlic aroma."
            },
            {
                "heat": "medium-high",
                "instruction": "Remove the asparagus from the pan and set aside with the potatoes. Add the remaining 30g of butter to the pan and increase heat to medium-high. Once butter is sizzling and lightly browned, carefully place the seasoned beef in the pan.",
                "time": 420,
                "whatToLookFor": "A deep brown crust forms on the beef. Cook to your desired doneness (e.g., 3-4 minutes per side for medium-rare)."
            },
            {
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
DAILY_LIMIT = len(API_KEYS) * 10

WEATHER_API_KEY = os.getenv('WEATHER_API_KEY')

gemini_service = GeminiService(API_KEYS)
smart_service = SmartRecipeService(WEATHER_API_KEY)
dashboard_service = DashboardService()

app = Flask(__name__)
CORS(app)

MAX_DAILY_REQUESTS = 40
request_count = 0

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


def generate_recipe_response(prompt, context=None):
    """Smart generation and Remix share the Gemini schema and response contract."""
    global request_count
    if not gemini_service.clients:
        return jsonify(success=False, error=gemini_service.configuration_error,
                       error_code='ai_not_configured'), 503
    if request_count >= DAILY_LIMIT:
        return jsonify(success=False, error='Daily quota exceeded',
                       error_code='ai_quota_error'), 429
    try:
        text = gemini_service.generate(prompt, response_schema=RecipeOutput.model_json_schema())
        request_count += 1
        recipe = RecipeOutput.model_validate_json(clean_json_response(text)).model_dump()
        payload = {'success': True, 'recipe': recipe,
                   'remaining_quota': max(0, DAILY_LIMIT - request_count)}
        if context is not None:
            payload['context'] = context
        return jsonify(payload)
    except GeminiConfigurationError as error:
        return jsonify(success=False, error=str(error), error_code='ai_not_configured'), 503
    except ValueError:
        return jsonify(success=False, error='AI returned an invalid recipe',
                       error_code='ai_invalid_recipe'), 422
    except GeminiRequestError as error:
        code = 'ai_quota_error' if error.status_code == 429 else 'ai_generation_error'
        return jsonify(success=False, error=str(error), error_code=code), (429 if error.status_code == 429 else 503)
    except Exception:
        app.logger.exception('Recipe generation failed')
        return jsonify(success=False, error='Recipe generation is unavailable',
                       error_code='ai_generation_error'), 503


# ==================== ROUTES ====================
@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'timestamp': datetime.utcnow().isoformat() + 'Z'})

@app.route('/api/quota', methods=['GET'])
def get_quota():
    return jsonify({
        'remaining': max(0, MAX_DAILY_REQUESTS - request_count),
        'limit': MAX_DAILY_REQUESTS
    })

@app.route('/api/dashboard', methods=['GET'])
def dashboard():
    day = request.args.get('date')
    return jsonify(dashboard_service.get_daily_brief(day))

@app.route('/api/generate-from-ingredients', methods=['POST'])
def generate():
    data = request.get_json()

    prompt = build_prompt(
        ingredients=data.get('ingredients'),
        tools=data.get('tools'),
        session_length=data.get('sessionLength', 'short'),
        difficulty=data.get('difficulty', 'normal'),
        dish=data.get('dish')
    )

    try:
        global request_count
        if request_count >= DAILY_LIMIT:
            return jsonify({
                'error': 'Daily quota exceeded',
                'success': False}), 429
        else:
            ai_text = gemini_service.generate(prompt)
            cleaned = clean_json_response(ai_text)
            print(f'Generated recipe: \n{cleaned}')
            request_count += 1
            parsed = json.loads(cleaned)
            if is_gemini_error(parsed):
                return jsonify({'success': False, 'error': parsed['error']}), 422
            return jsonify({
                'success': True,
                'recipe': parsed
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/smart-generate', methods=['POST'])
def smart_generate():
    try:
        req = SmartGenerateRequest(request.get_json(silent=True))
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

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

    )

    return generate_recipe_response(prompt, context)
    
@app.route('/api/generate-from-url', methods=['POST'])
def generate_from_url():
    data = request.get_json()
    url = data.get('url', '').strip()

    if not url:
        return jsonify({'error': 'URL is required'}), 400

    try:
        # 1. Get transcript
        transcript = get_youtube_transcript(url)

        # 2. Build prompt
        prompt = build_prompt_from_URL(transcript)

        print(f'\n📤 PROMPT SENT:\n{prompt}\n')

        # 3. Call Gemini
        ai_text = gemini_service.generate(prompt)

        print(f'\n📥 AI RAW RESPONSE:\n{ai_text}\n')

        # 4. Clean + parse
        cleaned = clean_json_response(ai_text)
        recipe = json.loads(cleaned)

        if is_gemini_error(recipe):
            return jsonify({'success': False, 'error': recipe['error']}), 422

        recipe['url'] = url
        image_url = find_hero_image(url)
        if image_url and not recipe.get('imageUrl'):
            recipe['imageUrl'] = image_url

        return jsonify({
            'success': True,
            'recipe': recipe
        })

    except Exception as e:
        print(f'❌ Error: {e}')
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

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
    data = request.get_json() or {}
    prompt = build_energy_note_prompt(data)

    try:
        ai_text = gemini_service.generate(prompt)
        cleaned = clean_json_response(ai_text)
        parsed = json.loads(cleaned)
        note = parsed.get('energyNote')
        if note:
            return jsonify({'success': True, 'energyNote': note})
    except Exception as e:
        print(f'Energy note fallback: {e}')

    ingredients = data.get('ingredients') or []
    tags = data.get('tags') or []
    tag_text = f" Tags: {', '.join(tags)}." if tags else ""
    return jsonify({
        'success': True,
        'energyNote': (
            f"This recipe has {len(ingredients)} main ingredients. Portion size "
            "and cooking fat will likely drive how heavy it feels, so pair it "
            f"with vegetables or a lighter side if needed.{tag_text}"
        )
    })

# ==================== RUN ====================

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=2975, debug=True)
