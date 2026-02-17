import 'package:flutter/material.dart';
import '../services/ai_interface.dart';
import '../services/gemini_service.dart';

class GenerateFromIngredientsModal extends StatefulWidget {
  const GenerateFromIngredientsModal({super.key});

  @override
  State<GenerateFromIngredientsModal> createState() =>
      _GenerateFromIngredientsModalState();
}

class _GenerateFromIngredientsModalState
    extends State<GenerateFromIngredientsModal> {
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _toolsController = TextEditingController();
  final AIInterface _aiService = GeminiService();

  String _sessionLength = 'short';
  String _difficulty = 'normal';
  String? _dish;

  bool _isGenerating = false;

  @override
  void dispose() {
    _ingredientsController.dispose();
    _toolsController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_ingredientsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter ingredients')));
      return;
    }

    setState(() => _isGenerating = true);

    final result = await _aiService.generateFromIngredients(
      ingredients: _ingredientsController.text.trim(),
      tools: _toolsController.text.trim().isNotEmpty
          ? _toolsController.text.trim()
          : null,
      dish: _dish,
      sessionLength: _sessionLength,
      difficulty: _difficulty,
    );

    setState(() => _isGenerating = false);

    if (mounted) {
      if (result.success && result.recipe != null) {
        Navigator.of(context).pop(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Generation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFEAEA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Generate Recipe',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ingredients
            const Text('Ingredients *', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'chicken, rice, onion...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Tools (optional)
            const Text('Tools (optional)', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _toolsController,
              decoration: const InputDecoration(
                hintText: 'pan, knife, pot...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Dish (optional)
            const Text('Dish Type (optional)', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _dish == null,
                  onSelected: (_) => setState(() => _dish = null),
                  selectedColor: const Color(0xFFFFA4A4),
                ),
                ...[
                  'Breakfast',
                  'Lunch',
                  'Dinner',
                  'Lazy meals',
                  'Dessert',
                  'Drinks',
                ].map(
                  (d) => ChoiceChip(
                    label: Text(d),
                    selected: _dish == d,
                    onSelected: (_) => setState(() => _dish = d),
                    selectedColor: const Color(0xFFFFA4A4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time
            const Text('Cooking Time', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['short', 'long'].map((t) {
                return ChoiceChip(
                  label: Text(t == 'short' ? 'Short' : 'Long'),
                  selected: _sessionLength == t,
                  onSelected: (_) => setState(() => _sessionLength = t),
                  selectedColor: const Color(0xFFFFA4A4),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Difficulty
            const Text('Difficulty', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['easy', 'normal', 'hard'].map((d) {
                return ChoiceChip(
                  label: Text(d[0].toUpperCase() + d.substring(1)),
                  selected: _difficulty == d,
                  onSelected: (_) => setState(() => _difficulty = d),
                  selectedColor: const Color(0xFFFFA4A4),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Generate Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA4A4),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Generating...'),
                        ],
                      )
                    : const Text(
                        'Generate Recipe',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
