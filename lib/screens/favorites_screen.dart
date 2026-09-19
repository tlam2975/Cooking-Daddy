import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../data/models/list_categories.dart';
import '../data/models/recipe.dart';
import '../data/repositories/recipe_repository.dart';
import '../theme/app_theme.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final RecipeRepository _repository = RecipeRepository();
  List<Recipe> recipes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => isLoading = true);
    final allRecipes = await _repository.getAllRecipes();
    if (!mounted) return;
    setState(() {
      recipes = allRecipes.where((recipe) => recipe.isFavorite).toList();
      isLoading = false;
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
      await _repository.updateRecipe(recipe);
    } catch (_) {
      if (!mounted) return;
      recipe.isFavorite = wasFavorite;
      recipe.updatedAt = DateTime.now();
      await _loadFavorites();
    }
  }

  Future<void> _openRecipe(Recipe recipe) async {
    await Navigator.pushNamed(context, '/recipeDetail', arguments: recipe.id);
    await _loadFavorites();
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
                              _FavoriteThumb(imageUrl: recipe.imageUrl),
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

class _FavoriteThumb extends StatelessWidget {
  final String? imageUrl;

  const _FavoriteThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: AppRadii.medium,
        child: Image.network(
          url,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadii.medium,
      ),
      child: Icon(Icons.menu_book_outlined, color: AppColors.primary),
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
