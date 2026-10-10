import os
import re
import threading
import time
import math

import requests


class NutritionLookupUnavailable(Exception):
    pass


class NutritionService:
    SEARCH_URL = 'https://world.openfoodfacts.org/cgi/search.pl'
    CACHE_SECONDS = 24 * 60 * 60
    SEARCH_INTERVAL_SECONDS = 6.1

    def __init__(self):
        self._cache = {}
        self._lock = threading.Lock()
        self._last_search = 0.0

    def build_note(self, recipe):
        language = recipe.get('language', 'en')
        if language not in ('en', 'vi'):
            language = 'en'
        ingredients = recipe.get('ingredients') or []
        if not isinstance(ingredients, list):
            ingredients = []
        ranked = sorted(
            (item for item in ingredients if isinstance(item, dict) and
             isinstance(item.get('name'), str) and item['name'].strip()),
            key=self._ingredient_weight,
            reverse=True,
        )
        matches = []
        for ingredient in ranked[:2]:
            result = self._search(ingredient['name'].strip())
            if result:
                matches.append({**result, 'ingredient': ingredient['name'].strip()})

        if not matches:
            note = ('Chưa tìm thấy dữ liệu dinh dưỡng phù hợp trên Open Food Facts cho nguyên liệu chính.'
                    if language == 'vi' else
                    'No matching nutrition data for the main ingredients was found in Open Food Facts.')
        else:
            examples = '; '.join(
                f"{match['name']}: {match['kcal']:g} kcal/100 g" for match in matches
            )
            if language == 'vi':
                note = (f'Ví dụ sản phẩm trên Open Food Facts: {examples}. '
                        'Giá trị thay đổi theo sản phẩm và cách chế biến; đây không phải tổng năng lượng cả món.')
            else:
                note = (f'Open Food Facts product examples: {examples}. '
                        'Values vary by product and preparation; this is not a whole-recipe total.')
        return {'energyNote': note, 'nutritionSource': 'Open Food Facts',
                'matchedIngredients': len(matches), 'ingredientCount': len(ranked),
                'products': matches}

    @staticmethod
    def _ingredient_weight(item):
        quantity = item.get('quantity')
        unit = item.get('unit')
        if not isinstance(quantity, (int, float)) or isinstance(quantity, bool):
            return 0
        if unit == 'kg':
            return quantity * 1000
        if unit == 'g':
            return quantity
        return 0

    def _search(self, name):
        key = name.lower()
        with self._lock:
            cached = self._cache.get(key)
            if cached and time.monotonic() - cached[0] < self.CACHE_SECONDS:
                return cached[1]
            remaining = self.SEARCH_INTERVAL_SECONDS - (time.monotonic() - self._last_search)
            if remaining > 0:
                time.sleep(remaining)
            self._last_search = time.monotonic()
            try:
                response = requests.get(
                    self.SEARCH_URL,
                    params={'search_terms': name, 'search_simple': 1,
                            'action': 'process', 'json': 1, 'page_size': 8,
                            'fields': 'code,product_name,nutriments,allergens_tags'},
                    headers={'User-Agent': os.getenv('OFF_USER_AGENT',
                             'CookingDaddy/2.0 (recipe app)')},
                    timeout=4,
                )
                response.raise_for_status()
                payload = response.json()
                if not isinstance(payload, dict) or not isinstance(payload.get('products'), list):
                    raise ValueError('Invalid product response')
                products = payload['products']
            except (requests.RequestException, ValueError, TypeError) as error:
                raise NutritionLookupUnavailable from error
            result = self._pick_match(name, products)
            self._cache[key] = (time.monotonic(), result)
            return result

    @staticmethod
    def _pick_match(name, products):
        def normalize(value):
            words = re.sub(r'[^\w\s]', ' ', value.lower()).split()
            return [word[:-3] + 'y' if word.endswith('ies') else
                    word[:-2] if word.endswith('oes') else
                    word[:-1] if word.endswith('s') and not word.endswith('ss') else
                    word for word in words]

        query = normalize(name)
        if not query:
            return None
        best = None
        best_extra = float('inf')
        for product in products:
            if not isinstance(product, dict):
                continue
            product_name = product.get('product_name')
            nutrients = product.get('nutriments') or {}
            kcal = nutrients.get('energy-kcal_100g') if isinstance(nutrients, dict) else None
            if (not isinstance(product_name, str) or
                    not isinstance(kcal, (int, float)) or isinstance(kcal, bool) or
                    not math.isfinite(kcal) or kcal < 0):
                continue
            words = normalize(product_name)
            if not all(word in words for word in query):
                continue
            extra_words = [word for word in words if word not in query]
            if any(word not in {'fresh', 'organic', 'raw', 'whole', 'bio',
                                'red', 'yellow', 'white'} for word in extra_words):
                continue
            extra = len(extra_words)
            if extra > 2 or extra >= best_extra:
                continue
            best = {'name': product_name.strip(), 'kcal': round(kcal)}
            best['nutrients'] = {}
            for nutrient in ('proteins', 'carbohydrates', 'fat', 'fiber', 'sugars', 'salt'):
                value = nutrients.get(f'{nutrient}_100g')
                if (isinstance(value, (int, float)) and not isinstance(value, bool)
                        and math.isfinite(value) and 0 <= value <= 100):
                    best['nutrients'][nutrient] = value
            allergens = product.get('allergens_tags')
            best['allergens'] = [tag for tag in allergens if isinstance(tag, str)] if isinstance(allergens, list) else []
            code = product.get('code')
            best['code'] = code if isinstance(code, str) and code.isdigit() else None
            best_extra = extra
        return best
