import 'dart:math';
import 'package:cooking_daddy/data/models/quotes.dart';
import '../data/models/recipe.dart';
import '../data/models/recipe_tags.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';
import '../data/repositories/recipe_repository.dart';
import '../services/ai_interface.dart';
import '../services/gemini_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../data/models/list_categories.dart';
import 'package:uuid/uuid.dart';

class RecipeEditorScreen extends StatefulWidget {
  final Recipe? recipe;

  const RecipeEditorScreen({super.key, this.recipe});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _toolsController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final AIInterface _aiService = GeminiService();
  bool _isGenerating = false;
  String? _imageUrl;

  late String randomQuote;

  final RecipeRepository _repository = RecipeRepository();

  List<StepData> steps = [StepData()];
  String? selectedCategoryKey; // ← CHANGED: Store KEY not display name

  Future<List<String>> _loadCategories() async {
    return CategoryData.getDisplayNames(context.locale.languageCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _ingredientsController.dispose();
    _toolsController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _addStep() {
    setState(() {
      steps.add(StepData());
    });
  }

  void _removeStep(int index) {
    if (steps.length > 1) {
      setState(() {
        steps.removeAt(index);
      });
    }
  }

  Future<void> _generateFromURL() async {
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('pleaseEnterURL'.tr())));
      return;
    }

    setState(() => _isGenerating = true);

    final result = await _aiService.generateFromUrl(_urlController.text.trim());

    setState(() => _isGenerating = false);

    if (result.success && result.recipe != null) {
      print('🟢 URL Generation SUCCESS: ${result.recipe!.name}');
      _fillFormWithRecipe(result.recipe!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${'recipeGenerated'.tr()}: ${result.recipe!.name}\n'
              '${result.remainingQuota ?? 0} ${'remainingQuota'.tr()}',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.error}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // FIXED: No more context.locale here!
  void _fillFormWithRecipe(Recipe recipe) {
    print('🔵 _fillFormWithRecipe called for: ${recipe.name}');

    setState(() {
      _nameController.text = recipe.name;
      _urlController.text = recipe.url ?? '';
      _ingredientsController.text = _formatIngredients(recipe.ingredients);
      _toolsController.text = _formatTools(recipe.tools);
      _tagsController.text = recipe.tags.join(', ');
      _imageUrl = recipe.imageUrl;

      // Store KEY directly - NO context.locale!
      selectedCategoryKey = recipe.categoryKey;
      print('🔵 Set categoryKey to: $selectedCategoryKey');

      // Fill steps
      steps = recipe.steps.map((step) {
        final stepData = StepData();
        stepData.instructionController.text = step.instruction;
        stepData.heatController.text = step.heat ?? '';
        stepData.seasoningsController.text = step.seasonings ?? '';

        if (step.timer != null) {
          stepData.timerMinController.text = (step.timer! ~/ 60).toString();
          stepData.timerSecController.text = (step.timer! % 60).toString();
        }

        stepData.notesController.text = step.notes ?? '';
        stepData.lookForController.text = step.whatToLookFor;
        return stepData;
      }).toList();

      if (steps.isEmpty) {
        steps = [StepData()];
      }
    });

    print('🔵 Form filled successfully!');
  }

  @override
  void initState() {
    super.initState();
    randomQuote = cookingQuotes[Random().nextInt(cookingQuotes.length)];

    print('🔵 Recipe Editor opened');
    print('🔵 widget.recipe is null? ${widget.recipe == null}');

    if (widget.recipe != null) {
      print('✅ Has recipe: ${widget.recipe!.name}');

      // Pre-fill basic fields
      _nameController.text = widget.recipe!.name;
      _urlController.text = widget.recipe!.url ?? '';
      _ingredientsController.text = _formatIngredients(
        widget.recipe!.ingredients,
      );
      _toolsController.text = _formatTools(widget.recipe!.tools);
      _tagsController.text = widget.recipe!.tags.join(', ');
      _imageUrl = widget.recipe!.imageUrl;

      // Store KEY - no context.locale!
      selectedCategoryKey = widget.recipe!.categoryKey;

      // Pre-fill steps
      steps = widget.recipe!.steps.map((step) {
        final stepData = StepData();
        stepData.instructionController.text = step.instruction;
        stepData.heatController.text = step.heat ?? '';
        stepData.seasoningsController.text = step.seasonings ?? '';

        if (step.timer != null) {
          stepData.timerMinController.text = (step.timer! ~/ 60).toString();
          stepData.timerSecController.text = (step.timer! % 60).toString();
        }

        stepData.notesController.text = step.notes ?? '';
        stepData.lookForController.text = step.whatToLookFor;
        return stepData;
      }).toList();

      if (steps.isEmpty) {
        steps = [StepData()];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFont = context.locale.languageCode == 'vi'
        ? 'DarleySans'
        : 'Caveat';

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
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'add_recipe'.tr(),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            color: const Color.fromARGB(255, 255, 230, 0),
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
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // URL Field
                    Row(
                      children: [
                        const Text(
                          'URL:',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: TextField(
                              controller: _urlController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Generate with AI button
                    Center(
                      child: ElevatedButton(
                        onPressed: _isGenerating
                            ? null
                            : () async {
                                if (_urlController.text.trim().isNotEmpty) {
                                  // Has URL → Generate from URL
                                  print('🔵 Generating from URL...');
                                  await _generateFromURL();
                                } else {
                                  // No URL → Open AI Features
                                  print('🔵 Opening AI Features modal...');

                                  final result = await Navigator.pushNamed(
                                    context,
                                    '/aiFeatures',
                                  );

                                  print(
                                    '🔵 Received result from AI Features: $result',
                                  );
                                  print(
                                    '🔵 Result type: ${result.runtimeType}',
                                  );

                                  if (result != null &&
                                      result is AIGenerationResult) {
                                    print('🔵 Result is AIGenerationResult');
                                    print('🔵 Success: ${result.success}');
                                    print(
                                      '🔵 Has recipe: ${result.recipe != null}',
                                    );

                                    if (result.success &&
                                        result.recipe != null) {
                                      print(
                                        '🟢 AI Generation SUCCESS: ${result.recipe!.name}',
                                      );

                                      _fillFormWithRecipe(result.recipe!);

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '✅ ${'recipeGenerated'.tr()}: ${result.recipe!.name}',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    } else {
                                      print(
                                        '🔴 Generation failed: ${result.error}',
                                      );

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('❌ ${result.error}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    print('🔴 Result is null or wrong type');
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isGenerating
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('analyzing'.tr()),
                                ],
                              )
                            : Text(
                                'generate_with_ai'.tr(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildHeroImagePreview(),
                    if (_imageUrl != null && _imageUrl!.isNotEmpty)
                      const SizedBox(height: 24),

                    _buildTextField('${'name'.tr()}*', _nameController),
                    const SizedBox(height: 16),

                    _buildTextField('ingredients'.tr(), _ingredientsController),
                    const SizedBox(height: 16),

                    _buildTextField('tools'.tr(), _toolsController),
                    const SizedBox(height: 24),

                    _buildTextField('Tags', _tagsController),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: RecipeTags.values.map((tag) {
                        return ActionChip(
                          label: Text(tag),
                          onPressed: () => _addTag(tag),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Steps
                    ...List.generate(steps.length, (index) {
                      return _buildStepCard(index);
                    }),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFEAEA),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Add Step Button
                        ElevatedButton(
                          onPressed: _addStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'add_step'.tr(),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),

                        // Category Dropdown - FIXED!
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: FutureBuilder<List<String>>(
                            future: _loadCategories(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox(
                                  width: 120,
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final categoryDisplayNames = snapshot.data!;

                              // Convert KEY → DISPLAY NAME (safe here in build)
                              String? selectedDisplay;
                              if (selectedCategoryKey != null) {
                                selectedDisplay = CategoryData.getDisplayName(
                                  selectedCategoryKey!,
                                  context.locale.languageCode,
                                );
                              }

                              return DropdownButton<String>(
                                value: selectedDisplay,
                                hint: Text(
                                  'category'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontFamily: currentFont,
                                ),
                                items: categoryDisplayNames.map((displayName) {
                                  return DropdownMenuItem<String>(
                                    value: displayName,
                                    child: Text(displayName),
                                  );
                                }).toList(),
                                onChanged: (String? newDisplayName) async {
                                  if (newDisplayName != null) {
                                    // Convert DISPLAY NAME → KEY
                                    final key =
                                        await CategoryData.getKeyFromDisplay(
                                          newDisplayName,
                                          context.locale.languageCode,
                                        );

                                    setState(() {
                                      selectedCategoryKey = key;
                                    });

                                    print(
                                      '🔵 Category changed to: $key (display: $newDisplayName)',
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            // Validate
                            if (_nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('pleaseEnterName'.tr()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (selectedCategoryKey == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('pleaseSelectCategory'.tr()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Create recipe
                            final now = DateTime.now();
                            final recipe = Recipe(
                              cloudId:
                                  widget.recipe?.cloudId ?? const Uuid().v4(),
                              name: _nameController.text.trim(),
                              url: _urlController.text.trim().isEmpty
                                  ? null
                                  : _urlController.text.trim(),
                              imageUrl: _imageUrl,
                              ingredients: _parseIngredients(
                                _ingredientsController.text,
                              ),
                              tools: _parseTools(_toolsController.text),
                              categoryKey: selectedCategoryKey!, // Use KEY
                              createdDate: widget.recipe?.createdDate ?? now,
                              updatedAt: now,
                              basePortions: widget.recipe?.basePortions ?? 1,
                              isFavorite: widget.recipe?.isFavorite ?? false,
                              isSeed: widget.recipe?.isSeed ?? false,
                              sourceRecipeId: widget.recipe?.sourceRecipeId,
                              energyNote: widget.recipe?.energyNote,
                              tags: _parseTags(_tagsController.text),
                              steps: steps.map((stepData) {
                                final timerMin =
                                    int.tryParse(
                                      stepData.timerMinController.text,
                                    ) ??
                                    0;
                                final timerSec =
                                    int.tryParse(
                                      stepData.timerSecController.text,
                                    ) ??
                                    0;
                                final totalSeconds = (timerMin * 60) + timerSec;

                                return Step(
                                  instruction: stepData
                                      .instructionController
                                      .text
                                      .trim(),
                                  heat:
                                      stepData.heatController.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : stepData.heatController.text.trim(),
                                  seasonings:
                                      stepData.seasoningsController.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : stepData.seasoningsController.text
                                            .trim(),
                                  timer: totalSeconds > 0 ? totalSeconds : null,
                                  notes:
                                      stepData.notesController.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : stepData.notesController.text.trim(),
                                  whatToLookFor: stepData.lookForController.text
                                      .trim(),
                                  index: steps.indexOf(stepData),
                                );
                              }).toList(),
                            );

                            if (widget.recipe != null) {
                              // Update
                              recipe.id = widget.recipe!.id;
                              await _repository.updateRecipe(recipe);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('recipe_updated'.tr()),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              // Add new
                              await _repository.addRecipe(recipe);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('recipeAdded'.tr()),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }

                            if (mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${'error'.tr()}: ${e.toString()}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB8E6F5),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'done'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
  }) {
    return Row(
      children: [
        isRequired
            ? RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$label:',
                      style: const TextStyle(fontSize: 18, color: Colors.black),
                    ),
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ],
                ),
              )
            : Text('$label:', style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroImagePreview() {
    final imageUrl = _imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 96,
            alignment: Alignment.center,
            color: Colors.white,
            child: const Icon(Icons.image_not_supported_outlined, size: 32),
          );
        },
      ),
    );
  }

  Widget _buildStepCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${'step'.tr()} ${index + 1}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle, size: 32),
                onPressed: () => _removeStep(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStepField(
            'instruction'.tr(),
            steps[index].instructionController,
          ),
          const SizedBox(height: 8),
          _buildStepField('heat'.tr(), steps[index].heatController),
          const SizedBox(height: 8),
          _buildStepField('seasonings'.tr(), steps[index].seasoningsController),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('timer'.tr(), style: TextStyle(fontSize: 16)),
              const SizedBox(width: 16),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: steps[index].timerMinController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const Text(' / ', style: TextStyle(fontSize: 20)),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: steps[index].timerSecController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStepField('notes'.tr(), steps[index].notesController),
          const SizedBox(height: 8),
          _buildStepField('lookFor'.tr(), steps[index].lookForController),
        ],
      ),
    );
  }

  Widget _buildStepField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text('$label:', style: const TextStyle(fontSize: 16)),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
            ),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatIngredients(List<Ingredient> ingredients) {
    return ingredients
        .map((ingredient) {
          final parts = <String>[];
          if (ingredient.quantity != null) {
            final q = ingredient.quantity!;
            parts.add(
              q == q.roundToDouble() ? q.toInt().toString() : q.toString(),
            );
          }
          if (ingredient.unit != null) parts.add(ingredient.unit!.name);
          parts.add(ingredient.name);
          final line = parts.join(' ').trim();
          return ingredient.note != null && ingredient.note!.isNotEmpty
              ? '$line (${ingredient.note})'
              : line;
        })
        .join(', ');
  }

  String _formatTools(List<Tool> tools) {
    return tools
        .map((tool) {
          if (tool.quantity != null && tool.quantity! > 1) {
            return '${tool.quantity}x ${tool.name}';
          }
          return tool.name;
        })
        .join(', ');
  }

  List<Ingredient> _parseIngredients(String text) {
    return text
        .split(',')
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .map(_parseIngredient)
        .toList();
  }

  Ingredient _parseIngredient(String raw) {
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(g|kg|ml|l|tsp|tbsp|cup|pcs)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(raw);

    if (match == null) return Ingredient(name: raw);

    return Ingredient(
      name: match.group(3)!.trim(),
      quantity: double.tryParse(match.group(1)!),
      unit: _parseUnit(match.group(2)),
    );
  }

  List<Tool> _parseTools(String text) {
    return text
        .split(',')
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .map((raw) {
          final match = RegExp(
            r'^(\d+)x\s+(.+)$',
            caseSensitive: false,
          ).firstMatch(raw);
          if (match == null) return Tool(name: raw, quantity: 1);
          return Tool(
            name: match.group(2)!.trim(),
            quantity: int.tryParse(match.group(1)!),
          );
        })
        .toList();
  }

  void _addTag(String tag) {
    final tags = _parseTags(_tagsController.text);
    if (!tags.contains(tag)) tags.add(tag);
    _tagsController.text = tags.join(', ');
  }

  List<String> _parseTags(String text) {
    return RecipeTags.normalizeAll(text.split(','));
  }

  MeasurementUnit? _parseUnit(String? value) {
    final unit = value?.trim().toLowerCase();
    if (unit == null || unit.isEmpty) return null;
    for (final candidate in MeasurementUnit.values) {
      if (candidate.name == unit) return candidate;
    }
    return null;
  }
}

class StepData {
  final TextEditingController instructionController = TextEditingController();
  final TextEditingController heatController = TextEditingController();
  final TextEditingController seasoningsController = TextEditingController();
  final TextEditingController timerMinController = TextEditingController();
  final TextEditingController timerSecController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController lookForController = TextEditingController();

  void dispose() {
    instructionController.dispose();
    heatController.dispose();
    seasoningsController.dispose();
    timerMinController.dispose();
    timerSecController.dispose();
    notesController.dispose();
    lookForController.dispose();
  }
}
