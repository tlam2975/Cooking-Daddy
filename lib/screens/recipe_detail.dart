import 'package:cooking_daddy/data/models/quotes.dart';
import 'package:flutter/material.dart' hide Step;
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../data/models/recipe.dart';
import '../data/repositories/recipe_repository.dart';
import '../services/energy_note_service.dart';
import '../services/shopping_cart.dart';
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
    print('=== DEBUG DETAIL ==='); //DEBUG LOG
    print('Widget recipeId: ${widget.recipeId}'); //DEBUG LOG

    setState(() {
      isLoading = true;
    });

    final fetchedRecipe = await _repository.getRecipe(widget.recipeId);

    print('Fetched recipe: ${fetchedRecipe?.name ?? "NULL"}'); //DEBUG LOG
    print('Fetched ID: ${fetchedRecipe?.id ?? "NULL"}'); //DEBUG LOG
    print('===================='); //DEBUG LOG

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
        color: const Color(0xFFFFA4A4).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFA4A4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFA4A4), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Khẩu phần',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Công thức gốc: $basePortions',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Giảm khẩu phần',
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Tăng khẩu phần',
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
        content: Text('Đã thêm nguyên liệu cho $selectedPortions khẩu phần'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final currentRecipe = recipe;
    if (currentRecipe == null) return;

    currentRecipe.isFavorite = !currentRecipe.isFavorite;
    currentRecipe.updatedAt = DateTime.now();
    await _repository.updateRecipe(currentRecipe);
    if (!mounted) return;

    setState(() {
      recipe = currentRecipe;
    });
  }

  Future<void> _createRemix() async {
    final currentRecipe = recipe;
    if (currentRecipe == null) return;

    final now = DateTime.now();
    final remix = Recipe(
      cloudId: const Uuid().v4(),
      name: '${currentRecipe.name} Remix',
      url: currentRecipe.url,
      imageUrl: currentRecipe.imageUrl,
      ingredients: currentRecipe.ingredients
          .map(
            (ingredient) => Ingredient(
              name: ingredient.name,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
              note: ingredient.note,
            ),
          )
          .toList(),
      tools: currentRecipe.tools
          .map((tool) => Tool(name: tool.name, quantity: tool.quantity))
          .toList(),
      steps: currentRecipe.steps
          .map(
            (step) => Step(
              instruction: step.instruction,
              heat: step.heat,
              index: step.index,
              seasonings: step.seasonings,
              timer: step.timer,
              notes: step.notes,
              whatToLookFor: step.whatToLookFor,
            ),
          )
          .toList(),
      categoryKey: currentRecipe.categoryKey,
      tags: currentRecipe.tags,
      createdDate: now,
      updatedAt: now,
      basePortions: currentRecipe.basePortions,
      sourceRecipeId: currentRecipe.sourceRecipeId ?? currentRecipe.cloudId,
    );

    await _repository.addRecipe(remix);
    if (!mounted) return;

    await Navigator.pushReplacementNamed(
      context,
      '/recipeEditor',
      arguments: remix,
    );
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFA4A4), width: 1),
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
                  label: const Text('Remix'),
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
                  label: const Text('Energy note'),
                ),
              ),
            ],
          ),
          if (energyNote != null && energyNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(energyNote, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFEAEA),
      body: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: const Color(0xFFFFA4A4),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Stack(
                children: [
                  // Back button
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 32,
                        color: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  if (recipe != null)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        tooltip: recipe!.isFavorite
                            ? 'Bỏ yêu thích'
                            : 'Yêu thích',
                        icon: Icon(
                          recipe!.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 32,
                          color: recipe!.isFavorite
                              ? const Color(0xFFFF6B6B)
                              : Colors.black,
                        ),
                        onPressed: _toggleFavorite,
                      ),
                    ),
                  // Title
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Cooking Daddy',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            color: Color.fromARGB(255, 255, 230, 0),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          randomQuote,
                          style: TextStyle(fontSize: 20, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : recipe == null
                  ? Center(child: Text('noRecipesFound'.tr()))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recipe Name
                          Center(
                            child: Text(
                              recipe!.name,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (recipe!.imageUrl != null &&
                              recipe!.imageUrl!.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                recipe!.imageUrl!,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 120,
                                    alignment: Alignment.center,
                                    color: Colors.white,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 32,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (recipe!.tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: recipe!.tags.map((tag) {
                                return Chip(label: Text(tag));
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                          _buildPortionSelector(),
                          const SizedBox(height: 16),
                          _buildRemixEnergyPanel(),
                          const SizedBox(height: 24),

                          // Ingredients Section
                          Text(
                            'ingredients'.tr(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _scaledIngredients()
                                  .map(ShoppingCart.instance.formatItem)
                                  .join('\n'),
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Tools Section (if available)
                          if (recipe!.tools.isNotEmpty) ...[
                            Text(
                              'tools'.tr(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                recipe!.tools.map(_formatTool).join('\n'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Number of Steps
                          // Number of Steps (Tappable)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showSteps = !showSteps; // Toggle visibility
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFA4A4),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${recipe!.steps.length} ${'stepCounter'.tr()}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    showSteps
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Show Steps if expanded
                          if (showSteps) ...[
                            const SizedBox(height: 16),
                            ...recipe!.steps.asMap().entries.map((entry) {
                              final index = entry.key;
                              final step = entry.value;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Step number
                                    Text(
                                      '${'step'.tr()} ${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFFA4A4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Instruction
                                    if (step.instruction.isNotEmpty) ...[
                                      Text(
                                        step.instruction,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],

                                    // Details row (heat, timer, seasonings)
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        if (step.heat != null &&
                                            step.heat!.isNotEmpty)
                                          _buildDetailChip(
                                            Icons.local_fire_department,
                                            step.heat!,
                                          ),

                                        if (step.timer != null &&
                                            step.timer! > 0)
                                          _buildDetailChip(
                                            Icons.timer,
                                            '${step.timer! ~/ 60}:${(step.timer! % 60).toString().padLeft(2, '0')}',
                                          ),

                                        if (step.seasonings != null &&
                                            step.seasonings!.isNotEmpty)
                                          _buildDetailChip(
                                            Icons.restaurant,
                                            step.seasonings!,
                                          ),
                                      ],
                                    ),

                                    // What to look for
                                    if (step.whatToLookFor.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF9E6),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFE082),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.visibility,
                                              size: 20,
                                              color: Color(0xFFFFA726),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${'lookFor'.tr()}: ${step.whatToLookFor}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Notes
                                    if (step.notes != null &&
                                        step.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE3F2FD),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.note,
                                              size: 20,
                                              color: Color(0xFF42A5F5),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                step.notes!,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],

                          const SizedBox(height: 100), // Space for button
                          const SizedBox(height: 100), // Space for button
                        ],
                      ),
                    ),
            ),
            // Start Button (Sticky Bottom)
            if (!isLoading && recipe != null)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAEA),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24.0),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addIngredientsToCart,
                            icon: const Icon(Icons.shopping_basket_outlined),
                            label: const Text('Thêm vào giỏ'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              side: const BorderSide(
                                color: Color(0xFFFFA4A4),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/cookingSession',
                                arguments: recipe,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB8E6F5),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'start_cooking'.tr(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
