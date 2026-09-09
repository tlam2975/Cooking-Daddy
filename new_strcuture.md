Cooking-Daddy/
├── lib/
│   ├── main.dart                              [MODIFIED — wire AuthGate as root]
│   ├── firebase_options.dart                  [NEW — from flutterfire configure]
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── isar_datasource.dart           [MODIFIED — seed recipes rewritten w/ structured ingredients/tools]
│   │   │   └── firestore_datasource.dart       [NEW — CRUD for users/{uid}/recipes, /categories]
│   │   │
│   │   ├── models/
│   │   │   ├── recipe.dart                    [MODIFIED — +cloudId, +isSeed, +updatedAt, +basePortions;
│   │   │   │                                    ingredients/tools → List<Ingredient>/List<Tool>]
│   │   │   ├── recipe.g.dart                   [MODIFIED — regenerated]
│   │   │   ├── ingredient.dart                 [NEW — embedded: name, amount, unit, notes]
│   │   │   ├── tool.dart                       [NEW — embedded: name, size, quantity]
│   │   │   ├── category.dart                   (unchanged)
│   │   │   ├── category.g.dart                 (unchanged)
│   │   │   ├── list_categories.dart            (unchanged — built-in keys, code-seeded)
│   │   │   ├── quotes.dart                     (unchanged)
│   │   │   └── user_profile.dart               [NEW — mirrors users/{uid} Firestore doc]
│   │   │
│   │   └── repositories/
│   │       ├── recipe_repository.dart          [MODIFIED — dual-write: Isar primary, Firestore best-effort]
│   │       └── auth_repository.dart            [NEW — wraps FirebaseAuth + GoogleSignIn]
│   │
│   ├── services/
│   │   ├── ai_interface.dart                   (unchanged)
│   │   ├── gemini_service.dart                 [MODIFIED — _convertToRecipe() maps structured shape directly]
│   │   ├── notification.dart                   (unchanged)
│   │   ├── quota_manager.dart                  (unchanged)
│   │   ├── timer.dart                          (unchanged)
│   │   └── migration/
│   │       └── migration_service.dart          [NEW — merge local ↔ cloud recipes/categories on sign-in]
│   │
│   ├── screens/
│   │   ├── ai_features.dart                    (unchanged)
│   │   ├── cooking_session.dart                (unchanged)
│   │   ├── home.dart                           (unchanged — recipe.id still local-only int, unaffected)
│   │   ├── profile.dart                        [MODIFIED — wire to real auth data, currently a placeholder]
│   │   ├── recipe_detail.dart                  (unchanged)
│   │   ├── recipe_editor.dart                  (unchanged, for now)
│   │   ├── settings.dart                       (unchanged)
│   │   └── auth/
│   │       ├── sign_in_screen.dart             [NEW — Google Sign-In]
│   │       └── migration_screen.dart           [NEW — progress UI during merge]
│   │
│   ├── utils/
│   │   ├── migrate_categories.dart             (unchanged — existing legacy local migration, decide
│   │   │                                          later whether migration_service.dart absorbs this)
│   │   ├── time_formatter.dart                 (unchanged)
│   │   └── validator.dart                      (unchanged)
│   │
│   └── widgets/
│       ├── generate_from_ingredients_modal.dart (unchanged)
│       ├── quota_indicator.dart                 (unchanged)
│       └── auth_gate.dart                       [NEW — root widget, drives sign-in → migration → home]
│
└── server/
    ├── __init__.py                             (unchanged)
    ├── gemini_service.py                        (unchanged)
    ├── main.py                                  [MODIFIED — build_prompt() emits structured ingredients/tools]
    ├── models.py                                (unchanged)
    ├── requirements.txt                         (unchanged)
    ├── service.py                                (unchanged)
    ├── test.py                                   [MODIFIED — build_prompt() (duplicate) + build_prompt_from_URL()
    │                                                + build_smart_prompt() all standardized on same contract]
    ├── test_youtube.py                          (unchanged)
    └── youtube_service.py                       (unchanged)