import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../data/models/list_categories.dart';
import '../data/models/recipe.dart';
import '../data/repositories/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_image.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final RecipeRepository _repository = RecipeRepository();
  List<Recipe> recipes = [];
  bool isLoading = true;
  StreamSubscription<List<Recipe>>? _recipesSubscription;

  @override
  void initState() {
    super.initState();
    _watchFavorites();
  }

  void _watchFavorites() {
    _recipesSubscription?.cancel();
    _recipesSubscription = _repository.watchAllRecipes().listen((allRecipes) {
      if (!mounted) return;
      setState(() {
        recipes = allRecipes.where((recipe) => recipe.isFavorite).toList();
        isLoading = false;
      });
    });
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final wasFavorite = recipe.isFavorite;
    recipe.isFavorite = !recipe.isFavorite;
    recipe.updatedAt = DateTime.now();
    setState(() {
      recipes = recipes.where((item) => item.id != recipe.id).toList();
    });

    try {
      await _repository.setFavorite(recipe, recipe.isFavorite);
    } catch (_) {
      if (!mounted) return;
      recipe.isFavorite = wasFavorite;
      recipe.updatedAt = DateTime.now();
    }
  }

  Future<void> _openRecipe(Recipe recipe) async {
    await Navigator.pushNamed(context, '/recipeDetail', arguments: recipe.id);
  }

  @override
  void dispose() {
    _recipesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('favorites'.tr(), style: AppTextStyles.greeting),
                const SizedBox(height: 4),
                Text(
                  recipes.isEmpty
                      ? 'favorites_empty_short'.tr()
                      : 'favorites_saved_count'.tr(
                          namedArgs: {'count': recipes.length.toString()},
                        ),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : recipes.isEmpty
                ? const _EmptyFavorites()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      return InkWell(
                        borderRadius: AppRadii.large,
                        onTap: () => _openRecipe(recipe),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.large,
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Row(
                            children: [
                              RecipeImage(
                                recipe: recipe,
                                width: 64,
                                height: 64,
                                borderRadius: AppRadii.medium,
                                fallbackIcon: Icons.menu_book_outlined,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.cardTitle,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${CategoryData.getDisplayName(recipe.categoryKey, context.locale.languageCode)}, ${recipe.steps.length} ${'stepCounter'.tr()}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'unfavorite'.tr(),
                                onPressed: () => _toggleFavorite(recipe),
                                icon: Icon(
                                  Icons.favorite,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemCount: recipes.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.favorite_border, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'favorites_empty_title'.tr(),
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 6),
            Text(
              'favorites_empty_message'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
