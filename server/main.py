from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from dotenv import load_dotenv
from datetime import datetime
from gemini_service import GeminiService
from models import SmartGenerateRequest
from prompts import build_prompt, build_smart_prompt, build_prompt_from_URL
from youtube_service import get_youtube_transcript
from service import SmartRecipeService

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
DAILY_LIMIT = len(API_KEYS) * 10

API_KEYS = [k for k in API_KEYS if k]

WEATHER_API_KEY = os.getenv('WEATHER_API_KEY')

gemini_service = GeminiService(API_KEYS)
smart_service = SmartRecipeService(WEATHER_API_KEY)

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
    global request_count
    try:
        req = SmartGenerateRequest(request.get_json())
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
        context["hour"]

    )

    print('🔵 ===== PROMPT DEBUG =====')
    print(f'🔵 Prompt type: {type(prompt)}')
    print(f'🔵 Prompt is None: {prompt is None}')
    print(f'🔵 Prompt length: {len(prompt) if prompt else 0}')
    print(f'🔵 Prompt content (first 500 chars):')
    print(prompt[:500] if prompt else 'PROMPT IS EMPTY/NONE!')
    print('🔵 ========================')
    
    # Validate
    if not prompt or prompt.strip() == '':
        return jsonify({
            'success': False,
            'error': 'Generated prompt is empty!'
        }), 500
    
    try:
        if request_count >= DAILY_LIMIT:
            return jsonify({
                'error': 'Daily quota exceeded',
                'success': False}), 429
        
        else:
            ai_text = gemini_service.generate(prompt)
            cleaned = clean_json_response(ai_text)
            request_count += 1
            print(f'Generated recipe: {cleaned}')
            parsed = json.loads(cleaned)
            if is_gemini_error(parsed):
                return jsonify({'success': False, 'error': parsed['error']}), 422
            return jsonify({
                'success': True,
                'recipe': parsed,
                'context': context
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
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

# ==================== RUN ====================

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=2975, debug=True)
