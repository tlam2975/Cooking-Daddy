# Cooking Daddy App Walkthrough

Last updated: 2026-09-18 07:43:08 +07

This file is a quick map of how the app is put together, so you can test and learn it without having to reverse-engineer every file at once.

## What This App Does

Cooking Daddy is a Flutter cooking assistant with:

- Local recipe storage in Isar.
- Firebase Auth and Firestore sync when signed in.
- AI recipe generation through a local Flask backend.
- Recipe import from ingredients or URL.
- Tags, favorites, shopping cart, portion scaling, recipe remix, energy notes, and dashboard tips.

The app treats Isar as the local source of truth. Firestore is a sync layer, not the only database.

## Main Flutter Entry Points

- `lib/main.dart`
  Starts Firebase, Isar, localization, notifications, theme preferences, then launches the app.

- `lib/widgets/auth_gate.dart`
  Decides whether to show sign-in or the signed-in app. When signed in, it runs one recipe sync before showing the main shell.

- `lib/widgets/main_shell.dart`
  Owns the bottom navigation tabs:
  Dashboard, Recipes, Shopping, Favorites, Settings.

- `lib/theme/app_theme.dart`
  Shared colors, text styles, radii, shadows, and Material theme setup.

- `lib/theme/theme_controller.dart`
  Stores the active theme preset and persists it with shared preferences.

## Main Screens

- `lib/screens/dashboard_screen.dart`
  First tab. Shows greeting, search entry, daily dashboard image/tip, and recent recipe suggestions.

- `lib/screens/home.dart`
  Recipes tab. Loads recipes from the repository, supports search/category filtering, edit/delete, favorite toggles, and opens recipe detail.

- `lib/screens/recipe_detail.dart`
  Recipe view. Shows hero image, title, tags, portion controls, remix, energy note, ingredients, tools, steps, add-to-cart, and start-cooking actions.

- `lib/screens/recipe_editor.dart`
  Add/edit recipe form. Can generate from URL or from the AI feature flow. Preserves image URL, tags, favorite state, source remix id, and energy note.

- `lib/screens/shopping_cart_screen.dart`
  In-memory shopping checklist. Items are not persisted yet.

- `lib/screens/favorites_screen.dart`
  Recipes where `isFavorite == true`.

- `lib/screens/cooking_session.dart`
  Step-by-step cooking mode with timer-related behavior.

## Data Layer

- `lib/data/models/recipe.dart`
  Core Isar model:
  `Recipe`, `Ingredient`, `Tool`, `Step`, and `MeasurementUnit`.

- `lib/data/datasources/isar_datasource.dart`
  Local database setup, seed categories, seed recipes, local CRUD.

- `lib/data/datasources/firestore_datasource.dart`
  Converts recipes to/from Firestore maps and handles delete tombstones.

- `lib/data/repositories/recipe_repository.dart`
  Main recipe API used by screens. Writes local first, then best-effort pushes to Firestore when signed in.

- `lib/services/recipe_sync_service.dart`
  Merge sync between local Isar and remote Firestore. Newer `updatedAt` wins; remote tombstones can delete local recipes.

## App Services

- `lib/services/gemini_service.dart`
  Flutter client for backend AI recipe generation and quota/health checks.

- `lib/services/dashboard_service.dart`
  Gets daily dashboard brief from Flask, caches per-user in Firestore, and falls back locally.

- `lib/services/energy_note_service.dart`
  Requests an energy note from Flask and falls back locally if backend is unavailable.

- `lib/services/shopping_cart.dart`
  In-memory cart, portion scaling, quantity rounding, item merging, and checklist state.

## Backend

Backend lives in `server/` and runs locally on port `2975`.

- `server/main.py`
  Flask routes:
  `/health`, `/api/quota`, `/api/dashboard`, `/api/smart-generate`, `/api/generate-from-url`, `/api/remix`, `/api/energy-note`.

- `server/prompts.py`
  Prompt contracts for structured recipe JSON and energy notes.

- `server/gemini_service.py`
  Backend Gemini wrapper.

- `server/service.py`
  Weather/time context for smart generation.

- `server/dashboard_service.py`
  Daily dashboard tip/image fallback content.

- `server/hero_image_service.py`
  Extracts `og:image`, Twitter image, or `image_src` from source URLs.

- `server/youtube_service.py`
  YouTube transcript fetching for URL generation.

## How To Run

### AI Remix

Open a saved recipe, tap **Remix**, and describe a change or choose **Vegetarian**, **Quicker**, or **Surprise me**. Leaving the request empty asks AI for a creative variation. Tap **Suggest a remix** and review the generated ingredients and steps in the editor. **Done** saves a new recipe; backing out discards the draft.

`RemixRecipeModal` calls `GeminiService.remixRecipe`, which posts the complete recipe, requested change, and app language to `/api/remix`. Flask builds the prompt in `prompts.py`, calls Gemini, and validates the response using `remix_service.py`. Errors stay in the modal so the request can be retried. Dismissing the modal ignores its eventual result, though the server may still finish the request and consume quota.

The draft gets a new UUID, preserves the base portion count and original `sourceRecipeId`, and is not written to Isar or Firestore until saved. The original recipe stays unchanged. Original photos and energy notes are not copied because they may not describe the new dish. The server must be running with a working Gemini API key; restart it after backend changes if automatic reload is disabled.

Focused checks (mocked AI, no quota consumed):

```bash
flutter test test/remix_service_test.dart test/remix_recipe_modal_test.dart
python3 -m unittest discover -s server -p 'test_remix.py' -v
```

### Start The App

From project root:

```bash
flutter pub get
```

Start backend:

```bash
cd server
python3 -B main.py
```

In another terminal, run app:

```bash
flutter run
```

For macOS release testing:

```bash
flutter run -d macos --release
```

iPhone release builds require Xcode signing:

- Open `ios/Runner.xcworkspace`.
- Add an Apple account in Xcode settings.
- Select the Runner target.
- Set the signing team.
- Make sure the bundle id is valid for that team.

## Useful Checks

```bash
flutter analyze --no-fatal-infos
flutter test test/shopping_cart_test.dart
python3 -B -m py_compile server/main.py server/prompts.py server/hero_image_service.py
```

Backend smoke tests:

```bash
curl http://127.0.0.1:2975/health
curl http://127.0.0.1:2975/api/dashboard
```

## Manual Test Checklist

- Sign in and reach the dashboard.
- Switch language between English and Vietnamese.
- Create a recipe manually.
- Generate a recipe from ingredients.
- Generate a recipe from a URL.
- Confirm generated URL recipes keep `imageUrl` when available.
- Favorite/unfavorite from recipe list and detail.
- Open Favorites and verify list updates.
- Change portions in recipe detail.
- Add ingredients to shopping cart.
- Check/uncheck and remove shopping items.
- Generate an energy note.
- Tap Remix, choose a suggestion or describe a change, then tap Suggest a remix.
- Confirm AI changes both ingredients and steps and opens the result in the editor.
- Cancel the editor and confirm no recipe was saved; generate again and tap Done to save a separate recipe.
- Start a cooking session.
- Test Firestore sync by signing in and reopening the app.

## Current Known Limitations

- Shopping cart is intentionally in-memory only.
- Live Firebase sync still needs real signed-in testing.
- Gemini and YouTube import quality depends on API keys, quota, and transcript availability.
- iOS physical-device release requires Xcode signing setup.
- Analyzer still reports existing info-level lints, mostly debug `print`, deprecated `withOpacity`, and async context warnings.

## Commit / Log Habit

User-facing or code changes are recorded in `changes_log.md` with full local timestamps from 2026-09-14 onward.
