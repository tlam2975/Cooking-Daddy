import 'package:flutter/material.dart';
import 'dart:math';
import '../data/models/quotes.dart';
import '../services/gemini_service.dart';
import '../services/ai_interface.dart';
import '../widgets/quota_indicator.dart';
import '../widgets/generate_from_ingredients_modal.dart';
import 'package:easy_localization/easy_localization.dart';

class AIFeaturesScreen extends StatefulWidget {
  const AIFeaturesScreen({super.key});

  @override
  State<AIFeaturesScreen> createState() => _AIFeaturesScreenState();
}

class _AIFeaturesScreenState extends State<AIFeaturesScreen> {
  final AIInterface url = GeminiService();
  final AIInterface _aiService = GeminiService();
  final TextEditingController _urlController = TextEditingController();

  bool _isHealthy = false;
  bool _isChecking = true;
  late String randomQuote;

  @override
  void initState() {
    super.initState();
    randomQuote = cookingQuotes[Random().nextInt(cookingQuotes.length)];
    // print('🔵 Recipe Editor opened with recipe: ${widget.recipe?.name ?? "null"}');
    _checkHealth();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    final healthy = await _aiService.checkHealth();
    if (mounted) {
      setState(() {
        _isHealthy = healthy;
        _isChecking = false;
        print(
          'Checking AI server health: ${healthy ? "Healthy" : "Unhealthy"}\nBase URL: ${url}',
        );
      });
    }
  }

  Future<void> _showGenerateFromIngredientsModal() async {
    final result = await showModalBottomSheet<AIGenerationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GenerateFromIngredientsModal(),
    );

    if (result != null) {
      if (result.success && result.recipe != null) {
        print('🟡 RAW result: $result');
        print('🟡 success: ${result.success}');
        print('🟡 recipe: ${result.recipe}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Generated: ${result.recipe!.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error if generation failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result.error ?? 'Failed to generate recipe'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // Pop AIFeatures screen and return result to recipe_editor
      if (mounted) {
        Navigator.pop(context, result);
        print('Popped back to /recipeEditor! with $result');
      }
    }
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
            // Header - Same style as RecipeEditor
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
                  // Title
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'aiFeatures'.tr(),
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
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Server Status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isChecking
                              ? Colors.grey
                              : _isHealthy
                              ? Colors.green
                              : Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isChecking
                                ? Icons.hourglass_empty
                                : _isHealthy
                                ? Icons.check_circle
                                : Icons.error,
                            color: _isChecking
                                ? Colors.grey
                                : _isHealthy
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isChecking
                                  ? 'checkingServer'.tr()
                                  : _isHealthy
                                  ? 'serverOnline'.tr()
                                  : 'serverOffline'.tr(),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              setState(() => _isChecking = true);
                              _checkHealth();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quota
                    const QuotaIndicator(),

                    const SizedBox(height: 32),

                    // Feature 1: Generate from Ingredients
                    _buildFeatureCard(
                      title: 'generate_from_ingredients'.tr(),
                      description: 'generate_from_recipe_description'.tr(),
                      icon: Icons.auto_awesome,
                      onTap: _showGenerateFromIngredientsModal,
                    ),

                    const SizedBox(height: 16),

                    // Feature 2: Generate from URL
                    _buildFeatureCard(
                      title: 'generate_from_url'.tr(),
                      description: 'generate_from_url_description'.tr(),
                      icon: Icons.link,
                      onTap: () => _showUrlDialog(),
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

  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isHealthy ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA4A4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showUrlDialog() async {
    // The "Generate from URL" feature should generate from the user input URL
    // This should probably be implemented in a modal similar to ingredients
    // For now, show a modal or dialog to get URL input
    final result = await showModalBottomSheet<AIGenerationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GenerateFromIngredientsModal(),
    );

    if (result != null) {
      if (result.success && result.recipe != null) {
        print('Result success: ${result.success}');
        print('Recipe: ${result.recipe}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Generated: ${result.recipe!.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error if generation failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result.error ?? 'Failed to generate recipe'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // Pop AIFeatures screen and return result to recipe_editor
      if (mounted) {
        Navigator.pop(context, result);
      }
    }
  }
}
