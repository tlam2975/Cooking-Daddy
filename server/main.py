import google.generativeai as genai
from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure Gemini
API_KEY = os.getenv('API_KEY')
genai.configure(api_key=API_KEY)
model = genai.GenerativeModel('gemini-2.5-flash')
#pls make sure its gemini-2.5-flash, cause other models just don't work alright?

# Flask app
app = Flask(__name__)
CORS(app)

# Configuration
MAX_DAILY_REQUESTS = 50
request_count = 0


# Build recipe from ingredients
def build_prompt(ingredients, tools=None, session_length='normal', difficulty='normal', dish=None):
    """Build prompt for recipe generation"""
    tools_str = f", tools: {tools}" if tools else ""
    dish_str = dish if dish else 'a meal'
    
    prompt = f"""Generate a recipe for {dish_str} using these ingredients: {ingredients}{tools_str}, session length: {session_length}, difficulty: {difficulty}.

Please return in this very specific fields: name, ingredients, tools, steps[step(instruction(str), heat(str), time(int), seasoning(str), notes(str), whatToLookFor(str))].

The fields name, steps(instruction, whatToLookFor) are required, the rest are optional.
Timer is saved in seconds as int (3 minutes 20 seconds will be saved as 200).

Please return the exact format as specified, and nothing else. Do not include any additional text or explanations. Make sure that all measurements are in metric units (grams, liters, centimeter etc.) and that the recipe is clear and easy to follow. Avoid using any non-standard formatting or markdown.
The response should be in JSON format."""
    
    print(f'Prompt: {prompt}')
    
    return prompt


#Extract recipe from URL
def build_url_prompt(url):
    """Build prompt for URL extraction"""
    prompt = f"""Extract a recipe from this URL: {url}

Please return in this very specific fields: name, ingredients, tools, steps[step(instruction(str), heat(str), time(int), seasoning(str), notes(str), whatToLookFor(str))].

The fields name, steps(instruction, whatToLookFor) are required, the rest are optional.
Timer is saved in seconds as int (3 minutes 20 seconds will be saved as 200).

Please return the exact format as specified, and nothing else. Do not include any additional text or explanations.
The response should be in JSON format."""
    
    print(f'Prompt: {prompt}')
    
    return prompt


def clean_json_response(text):
    """Remove markdown formatting from response"""
    text = text.strip()
    
    # Remove markdown code blocks
    if text.startswith('```json'):
        text = text[7:]
    elif text.startswith('```'):
        text = text[3:]
    
    if text.endswith('```'):
        text = text[:-3]

    print(f'Cleaned JSON: {text}')
    
    return text.strip()


def check_quota():
    """Check if quota is available"""
    global request_count
    if request_count >= MAX_DAILY_REQUESTS:
        return False
    return True


def increment_quota():
    """Increment request count"""
    global request_count
    request_count += 1

@app.route('/', methods=['GET'])
def home():
    """Home endpoint"""
    return jsonify({
        'message': 'Welcome to Cooking Daddy API Server',
        'version': '1.0.0',
        'server': 'Change to /health to see the status of the server'
    })
    

# Routes
@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'message': 'Cooking Daddy API Server is running'
    })


@app.route('/api/quota', methods=['GET'])
def quota():
    """Get remaining quota"""
    return jsonify({
        'remaining': max(0, MAX_DAILY_REQUESTS - request_count),
        'limit': MAX_DAILY_REQUESTS
    })


@app.route('/api/generate-from-ingredients', methods=['POST'])
def generate_from_ingredients():
    """Generate recipe from ingredients"""
    
    # Check quota
    if not check_quota():
        return jsonify({
            'error': 'Daily quota exceeded',
            'message': 'Try again tomorrow'
        }), 429
    
    # Get request data
    data = request.get_json()
    ingredients = data.get('ingredients', '').strip()
    tools = data.get('tools', '').strip() or None
    session_length = data.get('sessionLength', 'short')
    difficulty = data.get('difficulty', 'normal')
    dish = data.get('dish', '').strip() or None
    
    if not ingredients:
        return jsonify({'error': 'Ingredients are required'}), 400
    
    try:
        # Build prompt
        prompt = build_prompt(ingredients, tools, session_length, difficulty, dish)
        print(f'\n📤 PROMPT SENT:\n{prompt}\n')
        
        # Call Gemini
        response = model.generate_content(prompt)
        ai_text = response.text
        print(f'📥 AI RAW RESPONSE:\n{ai_text}\n')
        
        # Clean and parse
        cleaned = clean_json_response(ai_text)
        print(f'🧹 CLEANED JSON:\n{cleaned}\n')
        
        recipe = json.loads(cleaned)
        print(f'✅ PARSED RECIPE: {recipe.get("name", "Unknown")}\n')
        
        # Success
        increment_quota()
        return jsonify({
            'success': True,
            'recipe': recipe,
            'remaining_quota': MAX_DAILY_REQUESTS - request_count
        })
        
    except json.JSONDecodeError as e:
        print(f'❌ JSON Parse Error: {e}')
        return jsonify({
            'error': 'Invalid AI response format',
            'raw': ai_text
        }), 500
        
    except Exception as e:
        print(f'❌ Error: {e}')
        return jsonify({
            'error': str(e)
        }), 500


@app.route('/api/generate-from-url', methods=['POST'])
def generate_from_url():
    """Generate recipe from URL"""
    
    # Check quota
    if not check_quota():
        return jsonify({
            'error': 'Daily quota exceeded',
            'message': 'Try again tomorrow'
        }), 429
    
    # Get URL
    data = request.get_json()
    url = data.get('url', '').strip()
    
    if not url:
        return jsonify({'error': 'URL is required'}), 400
    
    try:
        # Build prompt
        prompt = build_url_prompt(url)
        print(f'\n📤 PROMPT SENT:\n{prompt}\n')
        
        # Call Gemini
        response = model.generate_content(prompt)
        ai_text = response.text
        print(f'📥 AI RAW RESPONSE:\n{ai_text}\n')
        
        # Clean and parse
        cleaned = clean_json_response(ai_text)
        print(f'🧹 CLEANED JSON:\n{cleaned}\n')
        
        recipe = json.loads(cleaned)
        print(f'✅ PARSED RECIPE: {recipe.get("name", "Unknown")}\n')
        
        # Success
        increment_quota()
        return jsonify({
            'success': True,
            'recipe': recipe,
            'remaining_quota': MAX_DAILY_REQUESTS - request_count
        })
        
    except json.JSONDecodeError as e:
        print(f'❌ JSON Parse Error: {e}')
        return jsonify({
            'error': 'Invalid AI response format',
            'raw': ai_text
        }), 500
        
    except Exception as e:
        print(f'❌ Error: {e}')
        return jsonify({
            'error': str(e)
        }), 500


# Run server
if __name__ == '__main__':
    if not API_KEY:
        print('❌ ERROR: API_KEY not found in .env')
        exit(1)
    
    PORT = 2975
    
    print('🚀 Cooking Daddy API Server')
    print(f'📍 http://localhost:{PORT}')
    print(f'💚 Health: http://localhost:{PORT}/health')
    print('')
    
    app.run(host='0.0.0.0', port=PORT, debug=True)