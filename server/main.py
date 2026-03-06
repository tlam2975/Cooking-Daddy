# import google.generativeai as genai
import google.genai
from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from dotenv import load_dotenv
from colorama import Fore, Style
import requests
from youtube_transcript_api import YouTubeTranscriptApi
import re
import logging
from fastapi import HTTPException
from bs4 import BeautifulSoup
from youtube_transcript_api._errors import (
    TranscriptsDisabled,
    NoTranscriptFound,
    VideoUnavailable,
    CouldNotRetrieveTranscript,
)

# Load environment variables
load_dotenv()

# Configure APIs
WEATHER_API_KEY = os.getenv('WEATHER_API_KEY')

API_KEYS = [
    os.getenv('GEMINI_API_KEY_1'),
    os.getenv('GEMINI_API_KEY_2'),
    os.getenv('GEMINI_API_KEY_3'),
    os.getenv('GEMINI_API_KEY_4'),
]

# Remove None values
API_KEYS = [key for key in API_KEYS if key]

if not API_KEYS:
    raise ValueError("No API keys found in .env file")

# Track which key to use next (round-robin)
current_key_index = 0

def get_next_api_key():
    """Get next API key in rotation"""
    global current_key_index
    key = API_KEYS[current_key_index]
    current_key_index = (current_key_index + 1) % len(API_KEYS)
    return key

def try_all_keys(prompt):
    """Try generation with all available API keys"""
    last_error = None
    
    for i, api_key in enumerate(API_KEYS):
        try:
            print(f'🔑 Trying API key #{i+1}')
            
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel('gemini-2.5-flash')  
            
            response = model.generate_content(prompt)
            
            print(f'✅ Success with key #{i+1}')
            return response
            
        except Exception as e:
            error_msg = str(e)
            print(f'❌ Key #{i+1} failed: {error_msg}')
            last_error = error_msg
            
            # Check if it's a quota error
            if '429' in error_msg or 'quota' in error_msg.lower():
                print(f'⚠️ Key #{i+1} quota exceeded, trying next...')
                continue
            else:
                # Other error, might work with another key
                continue
    
    # All keys failed
    raise Exception(f'All API keys exhausted. Last error: {last_error}')
#check https://aistudio.google.com/rate-limit for more models
# But gemini-2.5-flash is the only one that works ...
# Configure weather



# Flask app
app = Flask(__name__)
CORS(app)

# Configuration
MAX_DAILY_REQUESTS = 50
request_count = 0
order = 0


# Build recipe from ingredients
def build_prompt(ingredients, tools=None, session_length='normal', difficulty='normal', dish=None):
    """Build prompt for recipe generation"""
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
    
    global order
    order += 1
    print(f'{Fore.GREEN}Order: {order}{Style.RESET_ALL}')
    print(f'{Fore.CYAN}Prompt: {prompt}{Style.RESET_ALL}')
    
    return prompt


#Extract recipe from URL
def build_url_prompt(url: str) -> str:
    """
    Build prompt for URL-based recipe generation
    Handles both YouTube videos and regular webpages
    """
    
    # ========== YOUTUBE HANDLING ==========
    if 'youtube.com' in url or 'youtu.be' in url:
        try:
            from youtube_service import YouTubeService
            
            youtube_service = YouTubeService()
            
            # Extract video ID
            video_id = youtube_service.extract_video_id(url)
            print(f'🎥 YouTube video detected: {video_id}')
            
            # Get metadata
            metadata = youtube_service.get_video_metadata(url)
            print(f'📹 Video title: {metadata["title"]}')
            
            # Get transcript
            transcript_segments = youtube_service.get_transcript_detailed(
                video_id,
                languages=["en", "vi", "en-US", "en-GB"]
            )
            
            # Combine transcript text
            transcript_text = ' '.join(segment['text'] for segment in transcript_segments)
            
            print(f'✅ Got transcript: {len(transcript_text)} characters')
            
            # Build YouTube-specific prompt
            prompt = f"""Extract a recipe from this YouTube video transcript:

Video Title: {metadata['title']}
Uploader: {metadata.get('uploader', 'Unknown')}

Transcript:
{transcript_text}

Based on this transcript, extract the cooking recipe with exact instructions, ingredients, and timing mentioned in the video.
"""
            
        except Exception as e:
            print(f'❌ YouTube error: {e}')
            raise Exception(f"Could not get YouTube transcript: {str(e)}")
    
    # ========== WEBPAGE HANDLING ==========
    else:
        try:
            import requests
            from bs4 import BeautifulSoup
            
            print(f'{Fore.LIGHTBLUE_EX}🌐 Fetching webpage: {url}')
            
            response = requests.get(url, timeout=10)
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Remove scripts and styles
            for script in soup(["script", "style"]):
                script.decompose()
            
            # Get text
            text = soup.get_text()
            lines = (line.strip() for line in text.splitlines())
            text = '\n'.join(line for line in lines if line)
            
            # Get title
            title = soup.find('title')
            title_text = title.get_text() if title else 'Unknown'
            
            # Limit content
            content = text[:5000]
            
            print(f'✅ Got webpage: {len(content)} characters')
            
            # Build webpage-specific prompt
            prompt = f"""Extract a recipe from this webpage:

Title: {title_text}

Content:
{content}

Based on this webpage content, extract the cooking recipe.
"""
            
        except Exception as e:
            print(f'❌ Webpage error: {e}')
            raise Exception(f"Could not fetch webpage: {str(e)}")
    
    # ========== COMMON FORMAT REQUIREMENTS ==========
    prompt += """

Return ONLY a JSON object with this exact structure:
{
  "name": "Recipe name",
  "category": "Breakfast/Lunch/Dinner/Dessert/Drinks/Lazy meals",
  "ingredients": "ingredient1, ingredient2, ...",
  "tools": "tool1, tool2, ...",
  "steps": [
    {
      "instruction": "Step description",
      "heat": "High/Medium/Low/Off",
      "time": 200,
      "seasoning": "salt, pepper",
      "notes": "Tips",
      "whatToLookFor": "Visual cues"
    }
  ]
}

All measurements in metric (grams, liters, cm).
Timer in seconds as int.
Don't add too many extra ingredients beyond what's mentioned.
"""
    
    return prompt

def build_smart_prompt(ingredients, tools, dish, session_length, difficulty, 
                       weather, meal_time, current_hour):
    """Build context-aware prompt with weather and time"""
    
    tools_str = f", tools: {tools}" if tools else ""
    dish_str = dish if dish else "a meal"
    
    prompt = f"""Generate a recipe for {dish_str} using ingredients: {ingredients}{tools_str}

Requirements:
- Session length: {session_length}
- Difficulty: {difficulty}
"""
    
    # Add time context
    prompt += f"\nTime Context:\n- Current time: {meal_time} ({current_hour}:00)\n"
    
    # Time-specific suggestions
    if meal_time == 'breakfast':
        prompt += "- Suggest energizing breakfast foods\n"
    elif meal_time == 'lunch':
        prompt += "- Suggest moderate portions, balanced meal\n"
    elif current_hour >= 20:  # After 8pm
        prompt += "- CRITICAL: Late night cooking\n"
        prompt += "- Suggest QUICK recipes (max 15 minutes)\n"
        prompt += "- Light portions, easy to digest\n"
    elif meal_time == 'dinner':
        prompt += "- Suggest hearty dinner portions\n"
    
    # Add weather context if available
    if weather:
        temp = weather['temperature']
        condition = weather['condition']
        city = weather['city']
        
        prompt += f"\nWeather Context:\n- Location: {city}\n"
        prompt += f"- Temperature: {temp}°C (feels like {weather['feels_like']}°C)\n"
        prompt += f"- Condition: {condition}\n"
        
        # Temperature suggestions
        if temp > 30:
            prompt += "- VERY HOT: Suggest cold dishes, salads, no-cook meals\n"
        elif temp > 25:
            prompt += "- Warm: Light, refreshing meals\n"
        elif temp < 15:
            prompt += "- Cool: Warm, comforting dishes\n"
        elif temp < 10:
            prompt += "- COLD: Hot soups, stews, warming meals\n"
        
        # Weather condition
        if weather.get('is_raining'):
            prompt += "- RAINING: Perfect for hot soups, broths, comfort food\n"
        
        # Cultural context
        prompt += f"- Consider {city}'s local cuisine preferences\n"
    
    # Format requirements
    prompt += """
Please consider ALL context above when generating.

Return ONLY JSON format:
{
  "name": "Recipe name",
  "category": "Breakfast/Lunch/Dinner/Dessert/Drinks/Lazy meals",
  "ingredients": "ingredient1, ingredient2",
  "tools": "tool1, tool2",
  "steps": [
    {
      "instruction": "Step description",
      "heat": "High/Medium/Low/Off",
      "time": 200,
      "seasoning": "salt, pepper",
      "notes": "Tips",
      "whatToLookFor": "Visual cues"
    }
  ]
}

- All measurements in metric (grams, liters)
- Timer in seconds as int
- Don't add too many extra ingredients
- Suggest common Asian pantry items
"""
    
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
    return jsonify({
        'message': 'Welcome to Cooking Daddy API Server',
        'version': '1.0.0',
        'server': 'Change to /health to see the status of the server'
    })


@app.route('/health', methods=['GET'])
def health():
    # Health check endpoint
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
        response = try_all_keys(prompt)
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
        response = try_all_keys(prompt)
        ai_text = response.text
        print(f'📥 AI RAW RESPONSE:\n{ai_text}\n')
        
        # Clean and parse
        cleaned = clean_json_response(ai_text)
        print(f'{Fore.GREEN}🧹 CLEANED JSON:\n{cleaned}\n{Style.RESET_ALL}')
        
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

@app.route('/api/weather/<location>', methods=['GET'])
def get_weather(location):
    """Get weather for a location"""
    if not location:
        return jsonify({'error': 'Location is required'}), 400
    
    url = f'https://api.openweathermap.org/data/2.5/weather?q={location}&appid={WEATHER_API_KEY}&units=metric'
    
    try:
        response = requests.get(url)
        data = response.json()
        
        if response.status_code != 200:
            return jsonify({
                'error': data.get('message', 'Failed to fetch weather')
            }), response.status_code
        
        weather_info = {
            "weather": [{
                "main": data['weather'][0]['main'],
                "description": data['weather'][0]['description'],
            }],
            "main": {
                "temp": data['main']['temp'],
                "feels_like": data['main']['feels_like'],
                "temp_min": data['main']['temp_min'],
                "temp_max": data['main']['temp_max'],
                "humidity": data['main']['humidity'],
            },
            "rain": {
                "1h": data['rain']['1h'] if 'rain' in data and '1h' in data['rain'] else 0
            },
            "name": data['name'],
        }
        
        return jsonify(weather_info)  # ← Added return
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/api/smart-generate', methods=['POST'])
def smart_generate():
    """Context-aware recipe generation with weather"""
    
    data = request.get_json()
    
    # Required
    ingredients = data.get('ingredients', '').strip()
    if not ingredients:
        return jsonify({'error': 'Ingredients required'}), 400
    
    # Optional
    tools = data.get('tools', '').strip() or None
    dish = data.get('dish', '').strip() or None
    session_length = data.get('sessionLength', 'short')
    difficulty = data.get('difficulty', 'normal')
    location = data.get('location')  # City name (e.g., "Hanoi")
    
    # Get weather if location provided
    weather = None
    if location:
        try:
            weather_url = f'https://api.openweathermap.org/data/2.5/weather?q={location}&appid={WEATHER_API_KEY}&units=metric'
            weather_response = requests.get(weather_url)
            
            if weather_response.status_code == 200:
                weather_data = weather_response.json()
                weather = {
                    'temperature': weather_data['main']['temp'],
                    'feels_like': weather_data['main']['feels_like'],
                    'condition': weather_data['weather'][0]['main'],
                    'description': weather_data['weather'][0]['description'],
                    'humidity': weather_data['main']['humidity'],
                    'city': weather_data['name'],
                    'is_raining': 'rain' in weather_data and weather_data['rain'].get('1h', 0) > 0
                }
        except Exception as e:
            print(f'Weather fetch failed: {e}')
    
    # Get time context
    now = datetime.now()
    current_hour = now.hour
    
    if 6 <= current_hour < 11:
        meal_time = 'breakfast'
    elif 11 <= current_hour < 15:
        meal_time = 'lunch'
    else:
        meal_time = 'dinner'
    
    # Build smart prompt
    prompt = build_smart_prompt(
        ingredients=ingredients,
        tools=tools,
        dish=dish,
        session_length=session_length,
        difficulty=difficulty,
        weather=weather,
        meal_time=meal_time,
        current_hour=current_hour,
    )
    
    # Generate with Gemini
    try:
        response = try_all_keys(prompt)
        
        # Clean and parse
        cleaned = clean_json_response(response.text)
        recipe_data = json.loads(cleaned)
        
        return jsonify({
            'success': True,
            'recipe': recipe_data,
            'context': {
                'weather': weather,
                'meal_time': meal_time,
                'hour': current_hour
            }
        })
        
    except Exception as e:
        print(f'Generation error: {e}')
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Run server
if __name__ == '__main__':
    if not API_KEYS:
        print('❌ ERROR: GEMINI_API_KEY not found in .env')
        exit(1)
    
    PORT = 2975

    print('')
    print('🚀 Cooking Daddy API Server')
    print(f'{Fore.YELLOW}📍 http://localhost:{PORT}')
    print(f'💚 {Fore.YELLOW}Health: http://localhost:{PORT}/health')
    print('')
    
    app.run(host='0.0.0.0', port=PORT, debug=True)