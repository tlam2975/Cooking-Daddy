import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/models/list_categories.dart';
import '../data/models/recipe.dart';
import '../data/repositories/recipe_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_image.dart';
import 'package:easy_localization/easy_localization.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSearchTapped;
  const DashboardScreen({super.key, this.onSearchTapped});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final RecipeRepository _repository = RecipeRepository();
  StreamSubscription<List<Recipe>>? _recipesSubscription;
  List<Recipe> _recipes = [];
  List<Recipe> _suggestions = [];
  List<Recipe> _recentlyCooked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _watchDashboard();
  }

  void _watchDashboard() {
    _recipesSubscription?.cancel();
    _recipesSubscription = _repository.watchAllRecipes().listen((recipes) {
      if (!mounted) return;
      _applyRecipes(recipes);
    });
  }

  Future<void> _loadDashboard() async {
    final recipes = await _repository.getAllRecipes();
    if (!mounted) return;
    _applyRecipes(recipes);
  }

  void _applyRecipes(List<Recipe> recipes) {
    final recentlyCooked =
        recipes.where((recipe) => recipe.cookedAt.isNotEmpty).toList()
          ..sort((a, b) => _lastCookedAt(b).compareTo(_lastCookedAt(a)));

    final suggestions = List<Recipe>.from(recipes)
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));

    setState(() {
      _recipes = recipes;
      _recentlyCooked = recentlyCooked.take(4).toList();
      _suggestions = suggestions.take(4).toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _recipesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildSearchBar(context),
            const SizedBox(height: 28),
            Text('todays_suggestion'.tr(), style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            _buildSuggestions(),
            const SizedBox(height: 28),
            _buildStatsPanel(),
            const SizedBox(height: 28),
            Text('recently_cooked'.tr(), style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            _buildRecentlyCooked(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPanel() {
    final cookedThisMonth = _cookedThisMonth();
    final favoriteCount = _recipes.where((recipe) => recipe.isFavorite).length;
    final topCategory = _topCategory();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('kitchen_stats'.tr(), style: AppTextStyles.sectionTitle),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: [
              _StatTile(
                icon: Icons.local_fire_department_outlined,
                label: 'cooking_streak'.tr(),
                value: 'streak_days'.tr(
                  namedArgs: {'count': _cookingStreak().toString()},
                ),
              ),
              _StatTile(
                icon: Icons.calendar_month_outlined,
                label: 'cooked_this_month'.tr(),
                value: '$cookedThisMonth',
              ),
              _StatTile(
                icon: Icons.menu_book_outlined,
                label: 'saved_recipes'.tr(),
                value: '${_recipes.length}',
              ),
              _StatTile(
                icon: Icons.favorite_border,
                label: 'favorites'.tr(),
                value: '$favoriteCount',
              ),
            ],
          ),
          if (topCategory != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.insights_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'top_category'.tr(
                      namedArgs: {
                        'category': CategoryData.getDisplayName(
                          topCategory,
                          context.locale.languageCode,
                        ),
                      },
                    ),
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final greeting = displayName == null || displayName.isEmpty
        ? 'greeting_hello'.tr()
        : 'greeting_user'.tr(namedArgs: {'username': displayName});

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cooking Daddy',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                greeting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.greeting,
              ),
              const SizedBox(height: 2),
              Text(
                'what_to_cook_today'.tr(),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 23,
          backgroundColor: AppColors.primaryLight,
          foregroundImage: user?.photoURL == null
              ? null
              : NetworkImage(user!.photoURL!),
          child: user?.photoURL == null
              ? Icon(Icons.person_outline, color: AppColors.primary)
              : null,
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return InkWell(
      borderRadius: AppRadii.large,
      onTap: widget.onSearchTapped,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.large,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Text(
              'find_recipes'.tr(),
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text('no_recipes'.tr(), style: AppTextStyles.cardTitle),
            const SizedBox(height: 4),
            Text(
              'add_first_recipe'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }

    final featured = _suggestions.first;
    final remaining = _suggestions.skip(1);
    return Column(
      children: [
        _SuggestionCard(recipe: featured, featured: true),
        ...remaining.map(
          (recipe) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _SuggestionCard(recipe: recipe),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyCooked() {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_recentlyCooked.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.large,
          border: Border.all(color: AppColors.border),
        ),
        child: Text('cooking_history_empty'.tr(), style: AppTextStyles.caption),
      );
    }

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recentlyCooked.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final recipe = _recentlyCooked[index];
          return SizedBox(
            width: 270,
            child: _SuggestionCard(
              recipe: recipe,
              subtitle: _lastCookedLabel(recipe),
            ),
          );
        },
      ),
    );
  }

  int _cookingStreak() {
    final cookedDays = _recipes
        .expand((recipe) => recipe.cookedAt)
        .map(_dateOnly)
        .toSet();
    if (cookedDays.isEmpty) return 0;

    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    var cursor = cookedDays.contains(today) ? today : yesterday;
    if (!cookedDays.contains(cursor)) return 0;

    var streak = 0;
    while (cookedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _cookedThisMonth() {
    final now = DateTime.now();
    return _recipes.expand((recipe) => recipe.cookedAt).where((date) {
      return date.year == now.year && date.month == now.month;
    }).length;
  }

  String? _topCategory() {
    if (_recipes.isEmpty) return null;
    final counts = <String, int>{};
    for (final recipe in _recipes) {
      counts.update(
        recipe.categoryKey,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  DateTime _lastCookedAt(Recipe recipe) {
    return recipe.cookedAt.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String _lastCookedLabel(Recipe recipe) {
    final date = _lastCookedAt(recipe);
    final now = DateTime.now();
    final today = _dateOnly(now);
    final cookedDay = _dateOnly(date);
    if (cookedDay == today) return 'cooked_today'.tr();
    if (cookedDay == today.subtract(const Duration(days: 1))) {
      return 'cooked_yesterday'.tr();
    }
    return 'cooked_on'.tr(namedArgs: {'date': DateFormat.yMd().format(date)});
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _SuggestionCard extends StatelessWidget {
  final Recipe recipe;
  final String? subtitle;
  final bool featured;

  const _SuggestionCard({
    required this.recipe,
    this.subtitle,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final stepCount = recipe.steps.length;
    if (featured) {
      return InkWell(
        borderRadius: AppRadii.large,
        onTap: () {
          Navigator.pushNamed(context, '/recipeDetail', arguments: recipe.id);
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.large,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => RecipeImage(
                  recipe: recipe,
                  width: constraints.maxWidth,
                  height: 178,
                  borderRadius: BorderRadius.zero,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sectionTitle.copyWith(
                              fontSize: 19,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$stepCount ${'stepCounter'.tr()}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadii.small,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: AppRadii.large,
      onTap: () {
        Navigator.pushNamed(context, '/recipeDetail', arguments: recipe.id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.large,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            RecipeImage(
              recipe: recipe,
              width: 62,
              height: 62,
              borderRadius: AppRadii.medium,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: AppTextStyles.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ?? '$stepCount ${'stepCounter'.tr()}',
                    style: AppTextStyles.caption,
                  ),
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: recipe.tags.take(2).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: AppRadii.small,
                          ),
                          child: Text(
                            tag,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppRadii.small,
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
