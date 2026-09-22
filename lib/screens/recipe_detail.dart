import 'package:cooking_daddy/data/models/quotes.dart';
import 'package:flutter/material.dart' hide Step;
import 'dart:math';
import '../data/models/recipe.dart';
import '../data/repositories/recipe_repository.dart';
import '../services/energy_note_service.dart';
import '../services/shopping_cart.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_image.dart';
import '../widgets/remix_recipe_modal.dart';
// import '../data/models/quotes.dart';
import 'package:easy_localization/easy_localization.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId; // Pass ID instead of whole recipe

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final RecipeRepository _repository = RecipeRepository();
  final EnergyNoteService _energyNoteService = const EnergyNoteService();

  late String randomQuote;
  Recipe? recipe; // Nullable until loaded
  bool isLoading = true;
  bool isGeneratingEnergyNote = false;
  //Controls Step showing status
  bool showSteps = false;
  int selectedPortions = 1;

  @override
  void initState() {
    super.initState();
    randomQuote = cookingQuotes[Random().nextInt(cookingQuotes.length)];
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    setState(() {
      isLoading = true;
    });

    final fetchedRecipe = await _repository.getRecipe(widget.recipeId);

    setState(() {
      recipe = fetchedRecipe;
      selectedPortions = fetchedRecipe?.basePortions ?? 1;
      isLoading = false;
    });
  }

  String _formatTool(Tool t) {
    if (t.quantity != null && t.quantity! > 1) {
      return '${t.quantity}x ${t.name}';
    }
    return t.name;
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadii.small,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<ShoppingCartItem> _scaledIngredients() {
    final currentRecipe = recipe;
    if (currentRecipe == null) return [];

    return currentRecipe.ingredients
        .map(
          (ingredient) => ShoppingCart.instance.scaleIngredient(
            ingredient,
            currentRecipe.basePortions,
            selectedPortions,
          ),
        )
        .toList();
  }

  Widget _buildPortionSelector() {
    final basePortions = recipe?.basePortions ?? 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('portions'.tr(), style: AppTextStyles.cardTitle),
                const SizedBox(height: 2),
                Text(
                  'base_portions'.tr(
                    namedArgs: {'count': basePortions.toString()},
                  ),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'decrease_portions'.tr(),
            onPressed: selectedPortions <= 1
                ? null
                : () => setState(() => selectedPortions -= 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 44,
            child: Text(
              selectedPortions.toString(),
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle.copyWith(fontSize: 20),
            ),
          ),
          IconButton(
            tooltip: 'increase_portions'.tr(),
            onPressed: () => setState(() => selectedPortions += 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  void _addIngredientsToCart() {
    final currentRecipe = recipe;
    if (currentRecipe == null) return;

    ShoppingCart.instance.addRecipe(currentRecipe, selectedPortions);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'added_ingredients_for_portions'.tr(
            namedArgs: {'count': selectedPortions.toString()},
          ),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final currentRecipe = recipe;
    if (currentRecipe == null) return;

    final wasFavorite = currentRecipe.isFavorite;
    currentRecipe.isFavorite = !currentRecipe.isFavorite;
    currentRecipe.updatedAt = DateTime.now();
    setState(() {
      recipe = currentRecipe;
    });

    try {
      await _repository.setFavorite(currentRecipe, currentRecipe.isFavorite);
    } catch (_) {
      if (!mounted) return;
      currentRecipe.isFavorite = wasFavorite;
      currentRecipe.updatedAt = DateTime.now();
      setState(() {
        recipe = currentRecipe;
      });
    }
  }

  Future<void> _createRemix() async {
    final currentRecipe = recipe;
    if (currentRecipe == null) return;

    final remix = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (_) => RemixRecipeModal(source: currentRecipe),
    );
    if (!mounted || remix == null) return;
    await Navigator.pushNamed(context, '/recipeEditor', arguments: remix);
  }

  Future<void> _generateEnergyNote() async {
    final currentRecipe = recipe;
    if (currentRecipe == null || isGeneratingEnergyNote) return;

    setState(() => isGeneratingEnergyNote = true);
    final note = await _energyNoteService.generate(currentRecipe);
    currentRecipe.energyNote = note;
    currentRecipe.updatedAt = DateTime.now();
    await _repository.updateRecipe(currentRecipe);
    if (!mounted) return;

    setState(() {
      recipe = currentRecipe;
      isGeneratingEnergyNote = false;
    });
  }

  Widget _buildRemixEnergyPanel() {
    final energyNote = recipe?.energyNote;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createRemix,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text('remix'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.small),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isGeneratingEnergyNote
                      ? null
                      : _generateEnergyNote,
                  icon: isGeneratingEnergyNote
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_outlined),
                  label: Text('energy_note'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.small),
                  ),
                ),
              ),
            ],
          ),
          if (energyNote != null && energyNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(energyNote, style: AppTextStyles.body.copyWith(height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroImage(Recipe currentRecipe) {
    return RecipeImage(
      recipe: currentRecipe,
      width: double.infinity,
      height: currentRecipe.thumbnailSource == null ? 180 : 220,
      borderRadius: AppRadii.large,
    );
  }

  Widget _buildTags(Recipe currentRecipe) {
    if (currentRecipe.tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: currentRecipe.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppRadii.small,
          ),
          child: Text(
            tag,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildIngredientsList() {
    final items = _scaledIngredients();
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_box_outline_blank,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ShoppingCart.instance.formatItem(item),
                  style: AppTextStyles.body,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToolsList(Recipe currentRecipe) {
    return Column(
      children: currentRecipe.tools.map((tool) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(Icons.restaurant_menu, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_formatTool(tool), style: AppTextStyles.body),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsHeader(Recipe currentRecipe) {
    return InkWell(
      borderRadius: AppRadii.large,
      onTap: () => setState(() => showSteps = !showSteps),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadii.large,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${currentRecipe.steps.length} ${'stepCounter'.tr()}',
              style: AppTextStyles.sectionTitle.copyWith(color: Colors.white),
            ),
            Icon(
              showSteps ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(int index, Step step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'step'.tr()} ${index + 1}',
            style: AppTextStyles.cardTitle.copyWith(color: AppColors.primary),
          ),
          if (step.instruction.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              step.instruction,
              style: AppTextStyles.body.copyWith(height: 1.45),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (step.heat != null && step.heat!.isNotEmpty)
                _buildDetailChip(Icons.local_fire_department, step.heat!),
              if (step.timer != null && step.timer! > 0)
                _buildDetailChip(
                  Icons.timer,
                  '${step.timer! ~/ 60}:${(step.timer! % 60).toString().padLeft(2, '0')}',
                ),
              if (step.seasonings != null && step.seasonings!.isNotEmpty)
                _buildDetailChip(Icons.restaurant, step.seasonings!),
            ],
          ),
          if (step.whatToLookFor.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildStepNote(
              Icons.visibility,
              '${'lookFor'.tr()}: ${step.whatToLookFor}',
            ),
          ],
          if (step.notes != null && step.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildStepNote(Icons.note, step.notes!),
          ],
        ],
      ),
    );
  }

  Widget _buildStepNote(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadii.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRecipe = recipe;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Cooking Daddy',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                    ),
                  ),
                  if (currentRecipe != null)
                    IconButton(
                      tooltip: currentRecipe.isFavorite
                          ? 'unfavorite'.tr()
                          : 'favorite'.tr(),
                      icon: Icon(
                        currentRecipe.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: currentRecipe.isFavorite
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                      onPressed: _toggleFavorite,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : currentRecipe == null
                  ? Center(
                      child: Text(
                        'noRecipesFound'.tr(),
                        style: AppTextStyles.body,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroImage(currentRecipe),
                          const SizedBox(height: 20),
                          Text(
                            currentRecipe.name,
                            style: AppTextStyles.greeting.copyWith(
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            randomQuote,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildTags(currentRecipe),
                          if (currentRecipe.tags.isNotEmpty)
                            const SizedBox(height: 18),
                          _buildPortionSelector(),
                          const SizedBox(height: 14),
                          _buildRemixEnergyPanel(),
                          const SizedBox(height: 18),
                          _buildInfoCard(
                            title: 'ingredients'.tr(),
                            trailing: Text(
                              'base_portions'.tr(
                                namedArgs: {
                                  'count': selectedPortions.toString(),
                                },
                              ),
                              style: AppTextStyles.caption,
                            ),
                            child: _buildIngredientsList(),
                          ),
                          if (currentRecipe.tools.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildInfoCard(
                              title: 'tools'.tr(),
                              child: _buildToolsList(currentRecipe),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildStepsHeader(currentRecipe),
                          if (showSteps) ...[
                            const SizedBox(height: 12),
                            ...currentRecipe.steps.asMap().entries.map(
                              (entry) => _buildStepCard(entry.key, entry.value),
                            ),
                          ],
                          const SizedBox(height: 110),
                        ],
                      ),
                    ),
            ),
            if (!isLoading && currentRecipe != null)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: AppShadows.soft,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _addIngredientsToCart,
                          icon: const Icon(Icons.shopping_basket_outlined),
                          label: Text('add_to_cart'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.small,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/cookingSession',
                              arguments: currentRecipe,
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: Text('start_cooking'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.small,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
