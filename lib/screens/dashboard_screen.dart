import 'package:flutter/material.dart';
import '../data/models/recipe.dart';
import '../data/repositories/recipe_repository.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSearchTapped;
  const DashboardScreen({super.key, this.onSearchTapped});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final RecipeRepository _repository = RecipeRepository();
  final DashboardService _dashboardService = DashboardService();
  List<Recipe> _suggestions = [];
  DashboardBrief? _brief;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final recipes = await _repository.getAllRecipes();
    final brief = await _dashboardService.getDailyBrief();
    if (!mounted) return;
    setState(() {
      _suggestions = recipes.take(4).toList()
        ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
      _brief = brief;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadSuggestions,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildSearchBar(context),
            const SizedBox(height: 18),
            _buildDailyBrief(),
            const SizedBox(height: 28),
            Text('todays_suggestion'.tr(), style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            _buildSuggestions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBrief() {
    final brief = _brief;
    if (brief == null) {
      return Container(
        height: 156,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.large,
          border: Border.all(color: AppColors.border),
        ),
      );
    }

    return ClipRRect(
      borderRadius: AppRadii.large,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: Image.network(
              brief.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primaryLight,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.68)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brief.title,
                  style: AppTextStyles.cardTitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  brief.tip,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppRadii.medium,
          ),
          child: Icon(Icons.soup_kitchen_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('greeting_hello'.tr(), style: AppTextStyles.greeting),
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
          boxShadow: AppShadows.soft,
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

    return Column(
      children: _suggestions
          .map(
            (recipe) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SuggestionCard(recipe: recipe),
            ),
          )
          .toList(),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Recipe recipe;

  const _SuggestionCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final stepCount = recipe.steps.length;
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
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            _RecipeThumb(imageUrl: recipe.imageUrl, size: 62),
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
                    '$stepCount ${'stepCounter'.tr()}',
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

class _RecipeThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _RecipeThumb({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: AppRadii.medium,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadii.medium,
      ),
      child: Icon(Icons.ramen_dining_outlined, color: AppColors.primary),
    );
  }
}
