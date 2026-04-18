class SmartGenerateRequest:
    def __init__(self, data: dict):
        if not isinstance(data, dict):
            raise ValueError("Invalid request")

        self.ingredients = str(data.get('ingredients', '')).strip()
        self.tools = str(data.get('tools', '')).strip() or None
        self.dish = str(data.get('dish', '')).strip() or None
        self.session_length = data.get('sessionLength', 'short')
        self.difficulty = data.get('difficulty', 'normal')
        self.location = data.get('location')

        if not self.ingredients:
            raise ValueError("Ingredients required")