# from flask import Flask, request, jsonify
# from flask_cors import CORS
# import os
# import json
# import requests
# from dotenv import load_dotenv

# # Load .env from current directory
# load_dotenv()

# app = Flask(__name__)
# CORS(app)

# # Configuration
# GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
# GEMINI_URL = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent'
# MAX_DAILY_REQUESTS = 50

# # Simple quota tracking
# request_count = 0

# # Prompts
# PROMPT_FROM_URL = """
# Extract a recipe from this URL: {url}

# Return ONLY a JSON object with this exact structure (no markdown, no extra text):
# {{
#   "name": "Recipe name",
#   "category": "Breakfast/Lunch/Dinner/Dessert/Drinks/Lazy meals",
#   "ingredients": "ingredient 1, ingredient 2, ingredient 3",
#   "tools": "tool 1, tool 2",
#   "steps": [
#     {{
#       "instruction": "Step description",
#       "heat": "High/Medium/Low/Off",
#       "seasonings": "salt, pepper",
#       "timerMinutes": 5,
#       "timerSeconds": 30,
#       "notes": "Important tips",
#       "whatToLookFor": "Visual cues"
#     }}
#   ]
# }}
# """

# PROMPT_FROM_INGREDIENTS = """
# Create a simple recipe using these ingredients: {ingredients}

# Requirements:
# - Cooking time: {cooking_time}
# - Difficulty: {difficulty}
# - Meal type: {meal_type}

# Return ONLY a JSON object with this exact structure (no markdown, no extra text):
# {{
#   "name": "Recipe name",
#   "category": "{meal_type}",
#   "ingredients": "{ingredients}",
#   "tools": "suggested tools",
#   "steps": [
#     {{
#       "instruction": "Step description with beginner-friendly details",
#       "heat": "High/Medium/Low/Off",
#       "seasonings": "suggested seasonings",
#       "timerMinutes": 10,
#       "timerSeconds": 0,
#       "notes": "Tips for beginners",
#       "whatToLookFor": "What it should look like when done"
#     }}
#   ]
# }}

# Make it beginner-friendly with helpful visual cues.
# """


# # Helper Functions
# def clean_json(text):
#     """Remove markdown formatting from AI response"""
#     text = text.strip()
#     if text.startswith('```json'):
#         text = text[7:]
#     if text.startswith('```'):
#         text = text[3:]
#     if text.endswith('```'):
#         text = text[:-3]
#     return text.strip()


# def call_gemini(prompt):
#     """Call Gemini API with prompt"""
#     response = requests.post(
#         f'{GEMINI_URL}?key={GEMINI_API_KEY}',
#         headers={'Content-Type': 'application/json'},
#         json={'contents': [{'parts': [{'text': prompt}]}]},
#         timeout=30
#     )
    
#     if response.status_code != 200:
#         raise Exception(f'Gemini API error: {response.text}')
    
#     data = response.json()
#     return data['candidates'][0]['content']['parts'][0]['text']


# def check_quota():
#     """Check if quota is available"""
#     global request_count
#     if request_count >= MAX_DAILY_REQUESTS:
#         return False, jsonify({
#             'error': 'Daily quota exceeded',
#             'message': 'Try again tomorrow'
#         }), 429
#     return True, None, None


# def increment_quota():
#     """Increment request count"""
#     global request_count
#     request_count += 1


# # Routes
# @app.route('/health', methods=['GET'])
# def health():
#     """Health check"""
#     return jsonify({
#         'status': 'healthy',
#         'message': 'Server is running'
#     })


# @app.route('/api/quota', methods=['GET'])
# def quota():
#     """Get remaining quota"""
#     return jsonify({
#         'remaining': max(0, MAX_DAILY_REQUESTS - request_count),
#         'limit': MAX_DAILY_REQUESTS
#     })


# @app.route('/api/generate-from-url', methods=['POST'])
# def generate_from_url():
#     """Generate recipe from URL"""
#     # Check quota
#     ok, error_response, status_code = check_quota()
#     if not ok:
#         return error_response, status_code
    
#     # Get URL
#     data = request.get_json()
#     url = data.get('url', '').strip()
    
#     if not url:
#         return jsonify({'error': 'URL required'}), 400
    
#     try:
#         # Fill prompt and call AI
#         prompt = PROMPT_FROM_URL.format(url=url)
#         print(f'\n📤 PROMPT SENT:\n{prompt}\n')
        
#         ai_response = call_gemini(prompt)
#         print(f'📥 AI RAW RESPONSE:\n{ai_response}\n')
        
#         # Parse response
#         cleaned = clean_json(ai_response)
#         print(f'🧹 CLEANED JSON:\n{cleaned}\n')
        
#         recipe = json.loads(cleaned)
#         print(f'✅ PARSED RECIPE: {recipe["name"]}\n')
        
#         # Success
#         increment_quota()
#         return jsonify({
#             'success': True,
#             'recipe': recipe,
#             'remaining_quota': MAX_DAILY_REQUESTS - request_count
#         })
        
#     except json.JSONDecodeError:
#         return jsonify({
#             'error': 'Invalid AI response',
#             'raw': ai_response
#         }), 500
#     except Exception as e:
#         return jsonify({'error': str(e)}), 500


# @app.route('/api/generate-from-ingredients', methods=['POST'])
# def generate_from_ingredients():
#     """Generate recipe from ingredients"""
#     # Check quota
#     ok, error_response, status_code = check_quota()
#     if not ok:
#         return error_response, status_code
    
#     # Get data
#     data = request.get_json()
#     ingredients = data.get('ingredients', '').strip()
#     cooking_time = data.get('cookingTime', 'Quick')
#     difficulty = data.get('difficulty', 'Easy')
#     meal_type = data.get('mealType', 'Dinner')
    
#     if not ingredients:
#         return jsonify({'error': 'Ingredients required'}), 400
    
#     try:
#         # Fill prompt and call AI
#         prompt = PROMPT_FROM_INGREDIENTS.format(
#             ingredients=ingredients,
#             cooking_time=cooking_time,
#             difficulty=difficulty,
#             meal_type=meal_type
#         )
#         print(f'\n📤 PROMPT SENT:\n{prompt}\n')
        
#         ai_response = call_gemini(prompt)
#         print(f'📥 AI RAW RESPONSE:\n{ai_response}\n')
        
#         # Parse response
#         cleaned = clean_json(ai_response)
#         print(f'🧹 CLEANED JSON:\n{cleaned}\n')
        
#         recipe = json.loads(cleaned)
#         print(f'✅ PARSED RECIPE: {recipe["name"]}\n')
        
#         # Success
#         increment_quota()
#         return jsonify({
#             'success': True,
#             'recipe': recipe,
#             'remaining_quota': MAX_DAILY_REQUESTS - request_count
#         })
        
#     except json.JSONDecodeError:
#         return jsonify({
#             'error': 'Invalid AI response',
#             'raw': ai_response
#         }), 500
#     except Exception as e:
#         return jsonify({'error': str(e)}), 500


# # Run
# if __name__ == '__main__':
#     if not GEMINI_API_KEY:
#         print('❌ ERROR: GEMINI_API_KEY not found in .env')
#         exit(1)
    
#     PORT = 2975
    
#     print('🚀 Cooking Daddy API Server')
#     print(f'📍 http://localhost:{PORT}')
#     print(f'💚 Health: http://localhost:{PORT}/health')
#     print('')
    
#     app.run(host='0.0.0.0', port=PORT, debug=True)

import google.generativeai as genai
import os
from dotenv import load_dotenv

# Configure API key
load_dotenv()
API_KEY = os.getenv('API_KEY')
genai.configure(api_key=API_KEY)

# Initialize the model
model = genai.GenerativeModel('gemini-2.5-flash')
ingredients = 'potato, chicken thighs, onion, cheese'
tools = 'ladle, pot, pan'
sessionLength = 'short'
difficulty = 'easy'
dish = 'dinner'
prompt = f'Generate a recipe for {dish} using ingredients: {ingredients}, tools: {tools}, session length: {sessionLength}, difficulty: {difficulty}. Please return in this very specific fields: name, ingredients, tools, Step[step(instructions(str), heat(str), time(int), seasoning(str), notes(str), what to look for(str))]. The fields name, step(instruction, what to look for) are required, the rest are optional. Timer is saved in seconds int (3 minutes 20 seconds will be saved as 200). Please return the exact format as specified, and nothing else. Do not include any additional text or explanations. The response should be in JSON format.'


# Your message here
while (True):
    try:
        message = input("Enter your message (or 'quit' to exit): ")
        if message.lower() == 'quit':
            break
        # Generate response
        response = model.generate_content(message)
        print(response.text)
    except Exception as e:
        print(f"An error occurred: {e}")
    except KeyboardInterrupt:
        print("\nExiting...")
        break