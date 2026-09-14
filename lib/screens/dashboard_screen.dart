import 'package:flutter/material.dart';
import '../data/models/recipe.dart';
import '../data/repositories/recipe_repository.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';

/// "Trang chủ" — the new landing tab from the redesign.
/// Deliberately does NOT include the scoring/criteria stat cards from the
/// reference mockup — those are Phase 6 (dashboard scoring) content and
/// there's no real scoring logic to back them yet.
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSearchTapped; // must be nullable (VoidCallback?)
  const DashboardScreen({
    super.key,
    this.onSearchTapped,
  }); // must be optional (no "required")

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
      // No "suggested for you" logic exists yet — just showing the most
      // recently added recipes as a stand-in until that's designed.
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSearchBar(context),
            const SizedBox(height: 20),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Image.network(
              brief.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primaryLight,
                child: Icon(
                  Icons.image_not_supported,
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
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
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onSearchTapped,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
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
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(context, '/recipeDetail', arguments: recipe.id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Placeholder for the recipe photo — no photo field exists on
            // Recipe yet (that's Phase 3). Swap this for a real Image once
            // that field lands.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.ramen_dining_outlined,
                color: AppColors.primary,
              ),
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
                    stepCount == 1 ? '$stepCount bước' : '$stepCount bước',
                    style: AppTextStyles.caption,
                  ),
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
