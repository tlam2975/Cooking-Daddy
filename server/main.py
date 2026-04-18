from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from dotenv import load_dotenv
from datetime import datetime
from gemini_service import GeminiService
from models import SmartGenerateRequest
from service import SmartRecipeService

# Load env
load_dotenv()

API_KEYS = [
    os.getenv('GEMINI_API_KEY_1'),
    os.getenv('GEMINI_API_KEY_2'),
    os.getenv('GEMINI_API_KEY_3'),
    # os.getenv('GEMINI_API_KEY_4'),
]

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
    
    return f"""Generate a recipe for {dish_str} using these ingredients: {ingredients}{tools_str}, session length: {session_length}, difficulty: {difficulty}.

Please return in this very specific fields: name, ingredients, tools, steps[step(instruction(str), heat(str), time(int), seasoning(str), notes(str), whatToLookFor(str))].

The fields name, steps(instruction, whatToLookFor) are required, the rest are optional.
Timer is saved in seconds as int (3 minutes 20 seconds will be saved as 200).
You don't have to use all the ingredients, but try not to add to many extra ingredients that are not in the list. If you do add extra ingredients, make sure they are common pantry items. Also suggest the ingredients that are common in Asia.
Also note that the field "item" should return all items in a single string separated by comma, not a list. For example: "item1 40g, item2 2kg, item3 100g". Do not return it as a list.
Please return the exact format as specified, and nothing else. Do not include any additional text or explanations. If notes, heat and timer are blank, then simply leave them out of that step. Make sure that all measurements are in metric units (grams, liters, centimeter etc.) and that the recipe is clear and easy to follow. Avoid using any non-standard formatting or markdown.
The response should be in JSON format."""


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
    
    prompt += """\nReturn ONLY JSON format."""
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
        ai_text = gemini_service.generate(prompt)
        cleaned = clean_json_response(ai_text)
        print(f'Generated recipe: {cleaned}')
        return jsonify(json.loads(cleaned))
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/smart-generate', methods=['POST'])
def smart_generate():
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

    try:
        ai_text = gemini_service.generate(prompt)
        cleaned = clean_json_response(ai_text)

        return jsonify({
            'recipe': json.loads(cleaned),
            'context': context
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== RUN ====================

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=2975, debug=True)