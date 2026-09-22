class GeminiConfigurationError(RuntimeError):
    pass


class GeminiRequestError(RuntimeError):
    def __init__(self, status_code=None):
        self.status_code = status_code
        super().__init__('Gemini could not complete the request')


class GeminiService:
    def __init__(self, api_keys, model="gemini-2.5-flash"):
        self.model = model
        self.clients = []
        self.configuration_error = 'No Gemini API keys configured'

        if api_keys:
            try:
                import google.genai as genai
            except ImportError:
                self.configuration_error = 'Gemini SDK is not installed'
                return

            self.clients = [genai.Client(api_key=k) for k in api_keys]

    def generate(self, prompt: str, response_schema=None) -> str:
        if not self.clients:
            raise GeminiConfigurationError(self.configuration_error)

        last_error = None

        for i, client in enumerate(self.clients):
            try:
                print(f'🔑 Trying API key #{i+1}')

                config = {}
                if response_schema is not None:
                    config = {
                        'response_mime_type': 'application/json',
                        'response_json_schema': response_schema,
                    }
                response = client.models.generate_content(
                    model=self.model,
                    contents=[
                        {"role": "user", "parts": [{"text": prompt}]}
                    ],
                    config=config,
                )

                text = self._extract_text(response)

                # 🔥 VALIDATION STEP
                if not text or len(text.strip()) < 10:
                    raise Exception("Empty or invalid response")

                print(f'✅ Key #{i+1} success')
                return text

            except Exception as e:
                last_error = getattr(e, 'code', None)
                print(f'Gemini key #{i+1} failed (status: {last_error})')
                continue

        raise GeminiRequestError(last_error)

    def _extract_text(self, response):
        try:
            return response.text
        except:
            try:
                return response.candidates[0].content.parts[0].text
            except:
                raise Exception(f"Invalid response format: {response}")
        
