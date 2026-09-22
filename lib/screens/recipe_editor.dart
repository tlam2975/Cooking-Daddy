import 'dart:io';
import 'dart:math';
import 'package:cooking_daddy/data/models/quotes.dart';
import '../data/models/recipe.dart';
import '../data/models/recipe_tags.dart';
import '../services/step_activity.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';
import '../data/repositories/recipe_repository.dart';
import '../services/ai_interface.dart';
import '../services/gemini_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../data/models/list_categories.dart';
import '../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

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
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _ingredientsFocusNode = FocusNode();
  final AIInterface _aiService = GeminiService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isGenerating = false;
  String? _imageUrl;
  List<String> _photoSources = [];

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
    _nameFocusNode.dispose();
    _ingredientsFocusNode.dispose();
    for (final step in steps) {
      step.dispose();
    }
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
        final removed = steps.removeAt(index);
        removed.dispose();
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
      _photoSources = List<String>.from(recipe.photoSources);

      // Store KEY directly - NO context.locale!
      selectedCategoryKey = recipe.categoryKey;
      print('🔵 Set categoryKey to: $selectedCategoryKey');

      // Fill steps
      for (final step in steps) {
        step.dispose();
      }

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
        stepData.activityType = step.activityType;
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

      _fillFormWithRecipe(widget.recipe!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'add_recipe'.tr(),
                          style: AppTextStyles.greeting.copyWith(
                            fontSize: 30,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          randomQuote,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
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
                        Text(
                          'URL:',
                          style: AppTextStyles.sectionTitle.copyWith(
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.border,
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
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
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
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('analyzing'.tr()),
                                ],
                              )
                            : Text(
                                'generate_with_ai'.tr(),
                                style: AppTextStyles.cardTitle.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildPictureManager(),
                    const SizedBox(height: 24),

                    _buildTextField(
                      'name'.tr(),
                      _nameController,
                      isRequired: true,
                      focusNode: _nameFocusNode,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      'ingredients'.tr(),
                      _ingredientsController,
                      isRequired: true,
                      focusNode: _ingredientsFocusNode,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField('tools'.tr(), _toolsController),
                    const SizedBox(height: 24),

                    _buildTextField('tags'.tr(), _tagsController),
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
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: AppShadows.soft,
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
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: AppColors.primary,
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
                            style: AppTextStyles.cardTitle.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),

                        // Category Dropdown - FIXED!
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.medium,
                            border: Border.all(color: AppColors.border),
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
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                underline: const SizedBox(),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: AppColors.textPrimary,
                                ),
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 16,
                                ),
                                items: categoryDisplayNames.map((displayName) {
                                  return DropdownMenuItem<String>(
                                    value: displayName,
                                    child: Text(displayName),
                                  );
                                }).toList(),
                                onChanged: (String? newDisplayName) {
                                  if (newDisplayName != null) {
                                    // Convert DISPLAY NAME → KEY
                                    final key = CategoryData.getKeyFromDisplay(
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
                              _showValidationError(
                                'pleaseEnterName',
                                _nameFocusNode,
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

                            final ingredients = _parseIngredients(
                              _ingredientsController.text,
                            );
                            if (ingredients.isEmpty) {
                              _showValidationError(
                                'please_enter_ingredients',
                                _ingredientsFocusNode,
                              );
                              return;
                            }

                            final invalidStepIndex = steps.indexWhere(
                              (step) => step.instructionController.text
                                  .trim()
                                  .isEmpty,
                            );
                            if (invalidStepIndex != -1) {
                              _showValidationError(
                                'please_enter_step',
                                steps[invalidStepIndex].instructionFocusNode,
                              );
                              return;
                            }

                            final recipeSteps = steps.map((stepData) {
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

                              final instruction = stepData
                                  .instructionController
                                  .text
                                  .trim();
                              final heat = stepData.heatController.text.trim();
                              final seasonings = stepData
                                  .seasoningsController
                                  .text
                                  .trim();
                              final notes = stepData.notesController.text
                                  .trim();
                              final whatToLookFor = stepData
                                  .lookForController
                                  .text
                                  .trim();

                              return Step(
                                instruction: instruction,
                                heat: heat.isEmpty ? null : heat,
                                seasonings: seasonings.isEmpty
                                    ? null
                                    : seasonings,
                                timer: totalSeconds > 0 ? totalSeconds : null,
                                notes: notes.isEmpty ? null : notes,
                                whatToLookFor: whatToLookFor,
                                index: steps.indexOf(stepData),
                                activityType:
                                    stepData.activityType ??
                                    StepActivityResolver.infer(
                                      instruction: instruction,
                                      heat: heat,
                                      seasonings: seasonings,
                                      timer: totalSeconds,
                                      notes: notes,
                                      whatToLookFor: whatToLookFor,
                                    ),
                              );
                            }).toList();

                            // Create recipe
                            final now = DateTime.now();
                            final recipe = Recipe(
                              cloudId:
                                  widget.recipe?.cloudId.trim().isNotEmpty ==
                                      true
                                  ? widget.recipe!.cloudId.trim()
                                  : const Uuid().v4(),
                              name: _nameController.text.trim(),
                              url: _urlController.text.trim().isEmpty
                                  ? null
                                  : _urlController.text.trim(),
                              imageUrl: _imageUrl,
                              photoSources: _photoSources,
                              ingredients: ingredients,
                              tools: _parseTools(_toolsController.text),
                              categoryKey: selectedCategoryKey!, // Use KEY
                              createdDate: widget.recipe?.createdDate ?? now,
                              updatedAt: now,
                              basePortions: widget.recipe?.basePortions ?? 1,
                              isFavorite: widget.recipe?.isFavorite ?? false,
                              isSeed: widget.recipe?.isSeed ?? false,
                              cookedAt: widget.recipe?.cookedAt ?? const [],
                              sourceRecipeId: widget.recipe?.sourceRecipeId,
                              energyNote: widget.recipe?.energyNote,
                              tags: _parseTags(_tagsController.text),
                              steps: recipeSteps,
                            );

                            if (widget.recipe != null &&
                                widget.recipe!.id != Isar.autoIncrement) {
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'done'.tr(),
                          style: AppTextStyles.cardTitle.copyWith(
                            color: Colors.white,
                            fontSize: 18,
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

  void _showValidationError(String messageKey, FocusNode focusNode) {
    focusNode.requestFocus();
    final fieldContext = focusNode.context;
    if (fieldContext != null) {
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messageKey.tr()), backgroundColor: Colors.red),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    FocusNode? focusNode,
  }) {
    return Row(
      children: [
        isRequired
            ? RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$label:',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ],
                ),
              )
            : Text('$label:', style: AppTextStyles.body.copyWith(fontSize: 18)),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 2),
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
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

  Widget _buildPictureManager() {
    final canAddPhoto = _photoSources.length < 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
                child: Text(
                  'pictures'.tr(),
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                ),
              ),
              Text(
                'photo_count'.tr(args: ['${_photoSources.length}', '3']),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'take_picture'.tr(),
                onPressed: canAddPhoto ? _takePicture : null,
                icon: const Icon(Icons.add_a_photo_outlined),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          if (_photoSources.isEmpty) ...[
            const SizedBox(height: 8),
            _buildUrlImagePreview(),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photoSources.length,
                onReorder: _reorderPhoto,
                itemBuilder: (context, index) {
                  final source = _photoSources[index];
                  return Padding(
                    key: ValueKey(source),
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ReorderableDelayedDragStartListener(
                          index: index,
                          child: ClipRRect(
                            borderRadius: AppRadii.medium,
                            child: _buildPhoto(source),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.58),
                              borderRadius: AppRadii.small,
                            ),
                            child: Text(
                              index == 0 ? 'thumbnail'.tr() : '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton.filled(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            tooltip: 'remove_picture'.tr(),
                            onPressed: () => _removePhoto(index),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.58),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(30, 30),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.58),
                              borderRadius: AppRadii.small,
                            ),
                            child: Text(
                              _isRemoteSource(source)
                                  ? 'photo_cloud_copy'.tr()
                                  : 'photo_stored_on_device'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.58),
                                borderRadius: AppRadii.small,
                              ),
                              child: const Icon(
                                Icons.drag_handle,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrlImagePreview() {
    final imageUrl = _imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: AppRadii.medium,
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: AppColors.primary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: AppRadii.medium,
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 96,
            alignment: Alignment.center,
            color: AppColors.primaryLight,
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhoto(String source) {
    if (_isRemoteSource(source)) {
      return Image.network(
        source,
        width: 108,
        height: 108,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _photoFallback(),
      );
    }

    return Image.file(
      File(source),
      width: 108,
      height: 108,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _photoFallback(),
    );
  }

  Widget _photoFallback() {
    return Container(
      width: 108,
      height: 108,
      color: AppColors.primaryLight,
      child: Icon(Icons.broken_image_outlined, color: AppColors.primary),
    );
  }

  Future<void> _takePicture() async {
    if (_photoSources.length >= 3) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 84,
        maxWidth: 1600,
      );
      if (pickedFile == null) return;

      final savedPath = await _copyPhotoIntoAppStorage(pickedFile.path);
      if (!mounted) return;
      setState(() => _photoSources = [..._photoSources, savedPath]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('camera_unavailable'.tr())));
    }
  }

  Future<String> _copyPhotoIntoAppStorage(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${directory.path}/recipe_photos');
    if (!photosDir.existsSync()) {
      photosDir.createSync(recursive: true);
    }

    final sourceExtension = sourcePath.split('.').last.toLowerCase();
    const supportedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
    final extension = supportedExtensions.contains(sourceExtension)
        ? sourceExtension
        : 'jpg';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'recipe_$timestamp.$extension';
    final savedFile = await File(
      sourcePath,
    ).copy('${photosDir.path}/$fileName');
    return savedFile.path;
  }

  void _reorderPhoto(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final updated = List<String>.from(_photoSources);
      final source = updated.removeAt(oldIndex);
      updated.insert(newIndex, source);
      _photoSources = updated;
    });
  }

  void _removePhoto(int index) {
    setState(() {
      final updated = List<String>.from(_photoSources)..removeAt(index);
      _photoSources = updated;
    });
  }

  bool _isRemoteSource(String source) {
    final uri = Uri.tryParse(source);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Widget _buildStepCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${'step'.tr()} ${index + 1}',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
              ),
              IconButton(
                icon: Icon(
                  Icons.remove_circle,
                  size: 32,
                  color: AppColors.primary,
                ),
                onPressed: () => _removeStep(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStepField(
            'instruction'.tr(),
            steps[index].instructionController,
            focusNode: steps[index].instructionFocusNode,
          ),
          const SizedBox(height: 8),
          _buildStepField('heat'.tr(), steps[index].heatController),
          const SizedBox(height: 8),
          _buildStepField('seasonings'.tr(), steps[index].seasoningsController),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'timer'.tr(),
                style: AppTextStyles.body.copyWith(fontSize: 16),
              ),
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
              Text(' / ', style: AppTextStyles.body.copyWith(fontSize: 20)),
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

  Widget _buildStepField(
    String label,
    TextEditingController controller, {
    FocusNode? focusNode,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label:',
            style: AppTextStyles.body.copyWith(fontSize: 16),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
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
  StepActivityType? activityType;
  final TextEditingController instructionController = TextEditingController();
  final TextEditingController heatController = TextEditingController();
  final TextEditingController seasoningsController = TextEditingController();
  final TextEditingController timerMinController = TextEditingController();
  final TextEditingController timerSecController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController lookForController = TextEditingController();
  final FocusNode instructionFocusNode = FocusNode();

  void dispose() {
    instructionController.dispose();
    heatController.dispose();
    seasoningsController.dispose();
    timerMinController.dispose();
    timerSecController.dispose();
    notesController.dispose();
    lookForController.dispose();
    instructionFocusNode.dispose();
  }
}
