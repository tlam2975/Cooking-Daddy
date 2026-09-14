# Cooking Daddy Changes Log

## 2026-09-13

- Audited the current workspace against `/Users/macbuce/Downloads/cooking-daddy-item0-progress.md`.
- Confirmed Item 0 is only partially applied in this checkout.
- Found backend mismatch: `server/main.py` imports `prompts`, but `server/prompts.py` was missing.
- Found legacy backend files still present: `server/test.py` and `server/test_youtube.py`.
- Ran `flutter analyze`; remaining Item 0 errors are in seed data, AI conversion, recipe editor, and home search.
- Started applying approved Item 0 fixes.
- Added `server/prompts.py` with the structured recipe JSON contract.
- Removed obsolete backend scratch files `server/test.py` and `server/test_youtube.py`.
- Adjusted `server/main.py` quota counting and sample recipe boolean data.
- Made `server/gemini_service.py` allow health/debug routes to import without Gemini keys configured.
- Updated default seed recipes to use structured `Ingredient`/`Tool` lists, `cloudId`, `updatedAt`, and `isSeed`.
- Updated Gemini response conversion to parse structured ingredient/tool JSON and generate UUID-backed recipes.
- Updated the recipe editor to display structured ingredients/tools as text and parse edited text back into structured objects.
- Updated home search to scan ingredient/tool list contents instead of calling string methods on lists.
- Made Gemini's Python SDK import lazy so `/health` and debug endpoints can run even when Gemini dependencies or keys are not available.
- Made YouTube transcript imports lazy so the Flask app can start for health/debug checks without that optional package installed.
- Ran `python3 -B -m py_compile` for backend files successfully.
- Started Flask server with `python3 -B main.py`; `/health` returned status `ok`.
- Verified `/api/debug/sample-recipe` returns the structured recipe sample with list-based ingredients and tools.
- Ran `flutter analyze`; Item 0 compile errors are gone, with remaining output limited to existing analyzer info/lint items.
- Normalized server success responses to booleans and made the Dart client accept both boolean and legacy string success values.

## 2026-09-14

- Started Phase 1 work for portion scaling and the ephemeral shopping cart.
- Added an in-memory `ShoppingCart` service with unit-aware quantity rounding and item merging.
- Added the first real `ShoppingCartScreen` and wired the bottom-nav shopping tab plus `/shopping` route to it.
- Added portion controls to recipe detail, scaled ingredient display, and an action to add scaled ingredients to the in-memory shopping cart.
- Added focused tests for shopping cart portion scaling and item merging.
- Verified Phase 1 with `flutter test test/shopping_cart_test.dart` and `flutter analyze --no-fatal-infos`.
