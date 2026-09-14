RECIPE_JSON_SHAPE = """
{
  "name": "string",
  "category": "breakfast|lunch|dinner|dessert|drinks|lazy meals",
  "tags": ["quick|healthy|budget|comfort|spicy|vegetarian|high-protein|light|kid-friendly|one-pot|no-cook|meal-prep|breakfast|lunch|dinner|dessert|drink"],
  "ingredients": [
    {"name": "string", "quantity": 0, "unit": "g|kg|ml|l|tsp|tbsp|cup|pcs|null", "note": "string"}
  ],
  "tools": [
    {"name": "string", "quantity": 1}
  ],
  "steps": [
    {
      "instruction": "string",
      "heat": "string",
      "time": 0,
      "seasoning": "string",
      "notes": "string",
      "whatToLookFor": "string"
    }
  ]
}
"""

_JSON_RULES = """
Return only valid JSON. Do not include markdown fences or explanations.
Use this exact shape:
""" + RECIPE_JSON_SHAPE + """

Rules:
- Top-level "name", "category", "ingredients", "tools", and "steps" are required.
- Include 1-5 "tags" from this vocabulary only: quick, healthy, budget, comfort, spicy, vegetarian, high-protein, light, kid-friendly, one-pot, no-cook, meal-prep, breakfast, lunch, dinner, dessert, drink.
- Ingredient "name" is required.
- Ingredient "quantity", "unit", and "note" may be null when unknown.
- Ingredient "unit" must be one of: g, kg, ml, l, tsp, tbsp, cup, pcs, or null.
- Tool "name" is required; "quantity" may be null when unknown.
- Step "instruction" and "whatToLookFor" are required.
- Step "time" is saved in seconds as an integer, or null when unknown.
- Prefer metric measurements and common Asian pantry items.
- Do not add many extra ingredients beyond what the user provides.
- If a recipe cannot be generated, return {"error": "brief reason"}.
"""


def build_prompt(ingredients, tools=None, session_length='normal', difficulty='normal', dish=None):
    tools_str = f", tools: {tools}" if tools else ""
    dish_str = dish if dish else "a meal"

    prompt = f"""Generate a recipe for {dish_str} using these ingredients: {ingredients}{tools_str}.

Session length: {session_length}
Difficulty: {difficulty}

{_JSON_RULES}
"""
    print(f"Prompt built: {prompt}")
    return prompt


def build_smart_prompt(
    ingredients,
    tools,
    dish,
    session_length,
    difficulty,
    weather,
    meal_time,
    current_hour,
):
    tools_str = f", tools: {tools}" if tools else ""
    dish_str = dish if dish else "a meal"

    prompt = f"""Generate a recipe for {dish_str} using ingredients: {ingredients}{tools_str}.

Requirements:
- Session length: {session_length}
- Difficulty: {difficulty}

Time Context:
- Current time: {meal_time} ({current_hour}:00)
"""

    if meal_time == "breakfast":
        prompt += "- Suggest energizing breakfast foods\n"
    elif meal_time == "lunch":
        prompt += "- Suggest moderate portions and a balanced meal\n"
    elif current_hour >= 20:
        prompt += "- Late night cooking: suggest quick recipes, max 15 minutes\n"
        prompt += "- Keep portions light and easy to digest\n"
    elif meal_time == "dinner":
        prompt += "- Suggest hearty dinner portions\n"

    if weather:
        temp = weather["temperature"]
        condition = weather["condition"]
        city = weather["city"]

        prompt += f"\nWeather Context:\n- Location: {city}\n"
        prompt += f"- Temperature: {temp}C (feels like {weather['feels_like']}C)\n"
        prompt += f"- Condition: {condition}\n"

        if temp > 30:
            prompt += "- Very hot: suggest cold dishes, salads, or no-cook meals\n"
        elif temp > 25:
            prompt += "- Warm: prefer light, refreshing meals\n"
        elif temp < 10:
            prompt += "- Cold: prefer hot soups, stews, or warming meals\n"
        elif temp < 15:
            prompt += "- Cool: prefer warm, comforting dishes\n"

        if weather.get("is_raining"):
            prompt += "- Raining: soups, broths, and comfort foods fit well\n"

        prompt += f"- Consider {city}'s local cuisine preferences\n"

    prompt += f"\nPut all context above into consideration.\n\n{_JSON_RULES}"
    print(f"Prompt built: {prompt}")
    return prompt


def build_prompt_from_URL(transcript):
    prompt = f"""You are a strict JSON extractor. Do not summarize or paraphrase.

Task:
Extract a recipe from the transcript provided.

Rules:
- Only use information explicitly present in the transcript.
- Do not infer or add missing data.
- Use metric units if provided; do not convert if absent.
- If no recipe is present, return {{"error": "Transcript does not contain a recipe or cooking instructions"}}.

{_JSON_RULES}

Transcript:
{transcript}
"""
    print(f"Prompt built: {prompt}")
    return prompt


def build_energy_note_prompt(recipe):
    return f"""Write a short, practical energy note for this recipe.

Rules:
- Return JSON only: {{"energyNote": "string"}}
- Keep it under 45 words.
- Do not invent exact calories or medical claims.
- Mention what likely drives heaviness/lightness: protein, starch, fat, sugar, or portion size.

Recipe:
{recipe}
"""
