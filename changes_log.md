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
- Started Phase 2 favorites work.
- Added favorite toggles on recipe cards and recipe detail.
- Added the first real Favorites screen and wired the bottom-nav favorites tab plus `/favorites` route to it.
- Removed the unused in-shell placeholder tab now that Shopping and Favorites are real screens.
- Verified Phase 2 with `flutter analyze --no-fatal-infos`.
- Started Phase 3 tags work.
- Added a fixed Dart tag vocabulary and normalization helper.
- Updated Gemini conversion and backend prompt/sample contract to support suggested recipe tags.
- Added tags to built-in seed recipes.
- Added tag editing in the recipe editor with vocabulary chips and normalized comma-separated input.
- Added tag search and tag chips on home cards and recipe detail.
- Verified Phase 3 with `python3 -B -m py_compile server/main.py server/prompts.py`, `flutter analyze --no-fatal-infos`, and `flutter test test/shopping_cart_test.dart`.
- Started Phase 4 Firestore sync work.
- Added Firestore recipe serialization/deserialization and tombstone delete support.
- Added a recipe sync service that merges local/remote recipes by `cloudId` and `updatedAt`.
- Updated the recipe repository to best-effort push add/update changes and write tombstones on delete when signed in.
- Wired signed-in app startup through a one-shot recipe sync gate before showing the main shell.
- Verified Phase 4 statically with `flutter analyze --no-fatal-infos` and regression-tested `flutter test test/shopping_cart_test.dart`; live Firebase sync still needs signed-in manual testing.
