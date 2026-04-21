from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from dotenv import load_dotenv
from datetime import datetime
from gemini_service import GeminiService
from models import SmartGenerateRequest
from test import build_prompt_from_URL
from test_youtube import get_youtube_transcript
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
            "is_raining": 'false',
            "temperature": 30
        }
    },
    "recipe": {
        "ingredients": "beef sirloin 250g, asparagus 200g, unsalted butter 40g, potato 400g, salt, black pepper, vegetable oil 20ml, garlic cloves 2",
        "name": "Pan-Seared Beef with Garlicky Asparagus and Crispy Potatoes",
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
        "tools": "pan, knife, cutting board, tongs, spatula"
    },
    "success": "true"
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

# ==================== ORIGINAL PROMPTS (UNCHANGED) ====================

def check_quota():
    return request_count < MAX_DAILY_REQUESTS

def increment_quota():
    global request_count
    request_count += 1

def build_prompt(ingredients, tools=None, session_length='normal', difficulty='normal', dish=None):
    tools_str = f", tools: {tools}" if tools else ""
    dish_str = dish if dish else 'a meal'
    
    prompt = f"""Generate a recipe for {dish_str} using these ingredients: {ingredients}{tools_str}, session length: {session_length}, difficulty: {difficulty}.

Please return in this very specific fields: name, ingredients, tools, steps[step(instruction(str), heat(str), time(int), seasoning(str), notes(str), whatToLookFor(str))].

The fields name, steps(instruction, whatToLookFor) are required, the rest are optional.
Timer is saved in seconds as int (3 minutes 20 seconds will be saved as 200).
You don't have to use all the ingredients, but try not to add to many extra ingredients that are not in the list. If you do add extra ingredients, make sure they are common pantry items. Also suggest the ingredients that are common in Asia.
Also note that the field "item" should return all items in a single string separated by comma, not a list. For example: "item1 40g, item2 2kg, item3 100g". Do not return it as a list.
Please return the exact format as specified, and nothing else. Do not include any additional text or explanations. If notes, heat and timer are blank, then simply leave them out of that step. Make sure that all measurements are in metric units (grams, liters, centimeter etc.) and that the recipe is clear and easy to follow. Avoid using any non-standard formatting or markdown.
The response should be in JSON format."""
    print(f'Prompt built: {prompt}')  # Log the first 200 characters of the prompt for debugging

    return prompt


def build_smart_prompt(ingredients, tools, dish, session_length, difficulty, 
                       weather, meal_time, current_hour):
    tools_str = f", tools: {tools}" if tools else ""
    dish_str = dish if dish else "a meal"
    
    prompt = f"""Generate a recipe for {dish_str} using ingredients: {ingredients}{tools_str}

    Requirements:
    - Session length: {session_length}
    - Difficulty: {difficulty}
    """
    
    prompt += f"\nTime Context:\n- Current time: {meal_time} ({current_hour}:00)\n"
    
    if meal_time == 'breakfast':
        prompt += "- Suggest energizing breakfast foods\n"
    elif meal_time == 'lunch':
        prompt += "- Suggest moderate portions, balanced meal\n"
    elif current_hour >= 20:
        prompt += "- CRITICAL: Late night cooking\n"
        prompt += "- Suggest QUICK recipes (max 15 minutes)\n"
        prompt += "- Light portions, easy to digest\n"
    elif meal_time == 'dinner':
        prompt += "- Suggest hearty dinner portions\n"
    
    if weather:
        temp = weather['temperature']
        condition = weather['condition']
        city = weather['city']
        
        prompt += f"\nWeather Context:\n- Location: {city}\n"
        prompt += f"- Temperature: {temp}°C (feels like {weather['feels_like']}°C)\n"
        prompt += f"- Condition: {condition}\n"
        
        if temp > 30:
            prompt += "- VERY HOT: Suggest cold dishes\n"
        elif temp < 15:
            prompt += "- COOL: Warm dishes\n"
    
    prompt += """\nPlease return in this very specific fields: name, ingredients, tools, steps[step(instruction(str), heat(str), time(int), seasoning(str), notes(str), whatToLookFor(str))].

The fields name, steps(instruction, whatToLookFor) are required, the rest are optional.
Timer is saved in seconds as int (3 minutes 20 seconds will be saved as 200).
You don't have to use all the ingredients, but try not to add to many extra ingredients that are not in the list. If you do add extra ingredients, make sure they are common pantry items. Also suggest the ingredients that are common in Asia.
Also note that the field "item" should return all items in a single string separated by comma, not a list. For example: "item1 40g, item2 2kg, item3 100g". Do not return it as a list.
Please return the exact format as specified, and nothing else. Do not include any additional text or explanations. If notes, heat and timer are blank, then simply leave them out of that step. Make sure that all measurements are in metric units (grams, liters, centimeter etc.) and that the recipe is clear and easy to follow. Avoid using any non-standard formatting or markdown.
The response should be in JSON format. It must contain field 'success' with value 'true' if recipe is generated successfully, and 'false' if there is any issue with generating the recipe. If 'success' is 'false', then include an 'error' field with a brief error message. This is critical for the app to handle errors gracefully."""

    print(f'Prompt built: {prompt}') 

    return prompt


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
                'success': 'false'}), 429
        else:
            request_count += 1
            ai_text = gemini_service.generate(prompt)
            cleaned = clean_json_response(ai_text)
            print(f'Generated recipe: \n{cleaned}')
            request_count += 1
            return jsonify({
                'success': 'true',
                'recipe': json.loads(cleaned)
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
                'success': 'false'}), 429
        
        else:
            ai_text = gemini_service.generate(prompt)
            cleaned = clean_json_response(ai_text)
            request_count += 1
            print(f'Generated recipe: {cleaned}')
            return jsonify({
                'success': 'true',
                'recipe': json.loads(cleaned),
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
        # 1. Get transcript (your original function)
        transcript = get_youtube_transcript(url)

        # 2. Build prompt (UNCHANGED)
        prompt = build_prompt_from_URL(transcript)

        print(f'\n📤 PROMPT SENT:\n{prompt}\n')

        # 3. Call Gemini
        ai_text = gemini_service.generate(prompt)

        print(f'\n📥 AI RAW RESPONSE:\n{ai_text}\n')

        # 4. Clean + parse
        cleaned = clean_json_response(ai_text)
        recipe = json.loads(cleaned)

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