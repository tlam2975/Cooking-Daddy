class GeminiService:
    def __init__(self, api_keys, model="gemini-2.5-flash"):
        self.model = model
        self.clients = []

        if api_keys:
            import google.genai as genai

            self.clients = [genai.Client(api_key=k) for k in api_keys]

    def generate(self, prompt: str) -> str:
        if not self.clients:
            raise Exception("No Gemini API keys configured")

        last_error = None

        for i, client in enumerate(self.clients):
            try:
                print(f'🔑 Trying API key #{i+1}')

                response = client.models.generate_content(
                    model=self.model,
                    contents=[
                        {"role": "user", "parts": [{"text": prompt}]}
                    ]
                )

                text = self._extract_text(response)

                # 🔥 VALIDATION STEP
                if not text or len(text.strip()) < 10:
                    raise Exception("Empty or invalid response")

                print(f'✅ Key #{i+1} success')
                return text

            except Exception as e:
                last_error = str(e)
                print(f'❌ Key #{i+1} failed: {last_error}')
                continue

        raise Exception(f"All API keys failed: {last_error}")

    def _extract_text(self, response):
        try:
            return response.text
        except:
            try:
                return response.candidates[0].content.parts[0].text
            except:
                raise Exception(f"Invalid response format: {response}")
        
