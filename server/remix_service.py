import math


def valid_recipe(recipe):
    """Validate the structured fields consumed by the Flutter recipe converter."""
    if not isinstance(recipe, dict):
        return False
    for key in ('name', 'category'):
        if not isinstance(recipe.get(key), str) or not recipe[key].strip():
            return False
    for key in ('ingredients', 'tools', 'steps'):
        if not isinstance(recipe.get(key), list):
            return False
    if not recipe['ingredients'] or not recipe['steps']:
        return False
    if not isinstance(recipe.get('tags', []), list) or any(
        not isinstance(tag, str) for tag in recipe.get('tags', [])
    ):
        return False
    for key in ('ingredients', 'tools', 'steps'):
        for item in recipe[key]:
            required = 'instruction' if key == 'steps' else 'name'
            if not isinstance(item, dict) or not isinstance(item.get(required), str) or not item[required].strip():
                return False
            for field in ('note', 'heat', 'seasoning', 'notes', 'whatToLookFor'):
                if item.get(field) is not None and not isinstance(item[field], str):
                    return False
            number = item.get('time' if key == 'steps' else 'quantity')
            if number is not None:
                if isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) or number < 0:
                    return False
                if key != 'ingredients' and not isinstance(number, int):
                    return False
            if key == 'ingredients' and item.get('unit') not in (None, 'g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'cup', 'pcs'):
                return False
    return True
