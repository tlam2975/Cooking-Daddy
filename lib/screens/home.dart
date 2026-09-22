import 'package:flutter/material.dart';
import '../data/repositories/recipe_repository.dart';
import '../data/models/recipe.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_image.dart';
// import 'package:cooking_daddy/main.dart';
import 'package:easy_localization/easy_localization.dart';
import '../data/models/list_categories.dart';
import 'dart:async';

void main() {
  runApp(const CookingDaddyApp());
}

class CookingDaddyApp extends StatelessWidget {
  const CookingDaddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
      // theme: ThemeData(fontFamily: main.fontFamily),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RecipeRepository _repository = RecipeRepository();
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  List<Recipe> recipes = [];
  List<Recipe> filteredRecipes = [];
  String? selectedCategoryFilter;
  StreamSubscription<List<Recipe>>? _recipesSubscription;

  List<String> get categories {
    return CategoryData.getDisplayNames(context.locale.languageCode);
  }

  void _showDeleteConfirmation(Recipe recipe) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('delete'.tr()),
          content: Text('delete_confirmation'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () async {
                await _repository.deleteRecipe(recipe.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadRecipes();
              },
              child: Text('delete'.tr(), style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _watchRecipes();
    _searchController.addListener(_onSearchChanged);
  }

  void _watchRecipes() {
    _recipesSubscription?.cancel();
    _recipesSubscription = _repository.watchAllRecipes().listen((items) {
      if (!mounted) return;
      setState(() {
        recipes = items;
        isLoading = false;
      });
      _filterRecipes();
    });
  }

  Future<void> _loadRecipes() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    final fetchedRecipes = await _repository.getAllRecipes();

    if (mounted) {
      setState(() {
        recipes = fetchedRecipes;
        filteredRecipes = fetchedRecipes;
        isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final wasFavorite = recipe.isFavorite;
    recipe.isFavorite = !recipe.isFavorite;
    recipe.updatedAt = DateTime.now();
    _filterRecipes();

    try {
      await _repository.setFavorite(recipe, recipe.isFavorite);
    } catch (_) {
      if (!mounted) return;
      recipe.isFavorite = wasFavorite;
      recipe.updatedAt = DateTime.now();
      _filterRecipes();
    }
  }

  Future<void> _filterByCategory(String? categoryDisplay) async {
    if (categoryDisplay == null) {
      if (mounted) {
        setState(() {
          selectedCategoryFilter = null;
        });
      }
    } else {
      final key = CategoryData.getKeyFromDisplay(
        categoryDisplay,
        context.locale.languageCode,
      );

      if (mounted) {
        setState(() {
          selectedCategoryFilter = key;
        });
      }
    }

    _filterRecipes();
  }

  void _onSearchChanged() {
    _filterRecipes();
  }

  void _filterRecipes() {
    if (mounted) {
      setState(() {
        filteredRecipes = recipes.where((recipe) {
          final searchQuery = _searchController.text.toLowerCase();
          final ingredientText = recipe.ingredients
              .map(
                (ingredient) => [
                  ingredient.name,
                  ingredient.note,
                  ingredient.unit?.name,
                  ingredient.quantity?.toString(),
                ].whereType<String>().join(' '),
              )
              .join(' ')
              .toLowerCase();
          final toolText = recipe.tools
              .map(
                (tool) => [
                  tool.name,
                  tool.quantity?.toString(),
                ].whereType<String>().join(' '),
              )
              .join(' ')
              .toLowerCase();
          final tagText = recipe.tags.join(' ').toLowerCase();
          final matchesSearch =
              searchQuery.isEmpty ||
              recipe.name.toLowerCase().contains(searchQuery) ||
              ingredientText.contains(searchQuery) ||
              toolText.contains(searchQuery) ||
              tagText.contains(searchQuery);

          final matchesCategory =
              selectedCategoryFilter == null ||
              recipe.categoryKey == selectedCategoryFilter;

          return matchesSearch && matchesCategory;
        }).toList();
      });
    }
  }

  Future<void> _openRecipe(Recipe recipe) async {
    await Navigator.pushNamed(context, '/recipeDetail', arguments: recipe.id);
    _loadRecipes();
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: AppRadii.large,
        onTap: () => _openRecipe(recipe),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              RecipeImage(
                recipe: recipe,
                width: 92,
                height: 92,
                borderRadius: AppRadii.medium,
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
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${CategoryData.getDisplayName(recipe.categoryKey, context.locale.languageCode)}, ${recipe.steps.length} ${'stepCounter'.tr()}',
                      style: AppTextStyles.caption,
                    ),
                    if (recipe.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        recipe.tags.take(2).join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: recipe.isFavorite
                        ? 'unfavorite'.tr()
                        : 'favorite'.tr(),
                    onPressed: () => _toggleFavorite(recipe),
                    icon: Icon(
                      recipe.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: recipe.isFavorite
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.pushNamed(
                          context,
                          '/recipeEditor',
                          arguments: recipe,
                        );
                        _loadRecipes();
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(recipe);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit),
                            const SizedBox(width: 12),
                            Text('edit'.tr()),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, color: Colors.red),
                            const SizedBox(width: 12),
                            Text(
                              'delete'.tr(),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        tooltip: 'add_recipe'.tr(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () async {
          await Navigator.pushNamed(context, '/recipeEditor');
          _loadRecipes();
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('recipes'.tr(), style: AppTextStyles.greeting),
                      const SizedBox(height: 3),
                      Text(
                        '${filteredRecipes.length} ${'recipes'.tr().toLowerCase()}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'add_recipe'.tr(),
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/recipeEditor');
                    _loadRecipes();
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'find_recipes'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'clear'.tr(),
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryFilter(
                    label: 'all_recipes'.tr(),
                    selected: selectedCategoryFilter == null,
                    onTap: () => _filterByCategory(null),
                  ),
                  ...categories.map((category) {
                    final key = CategoryData.getKeyFromDisplay(
                      category,
                      context.locale.languageCode,
                    );
                    return _CategoryFilter(
                      label: category,
                      selected: selectedCategoryFilter == key,
                      onTap: () => _filterByCategory(category),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (filteredRecipes.isEmpty)
              _RecipeEmptyState(
                filtered:
                    _searchController.text.isNotEmpty ||
                    selectedCategoryFilter != null,
              )
            else
              ...filteredRecipes.map(_buildRecipeCard),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recipesSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged); // ← Remove listener
    _searchController.dispose(); // ← Dispose controller
    super.dispose();
  }
}

class _CategoryFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryLight,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.small),
        labelStyle: AppTextStyles.caption.copyWith(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RecipeEmptyState extends StatelessWidget {
  final bool filtered;

  const _RecipeEmptyState({required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.search_off : Icons.menu_book_outlined,
            size: 42,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            filtered ? 'noRecipesFound'.tr() : 'noRecipesYet'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 6),
          Text(
            filtered ? 'tryDifferentSearch'.tr() : 'addRecipeDefault'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
