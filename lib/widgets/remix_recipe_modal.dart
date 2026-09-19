import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../data/models/recipe.dart';
import '../services/ai_interface.dart';
import '../services/gemini_service.dart';

class RemixRecipeModal extends StatefulWidget {
  final Recipe source;
  final AIInterface? aiService;

  const RemixRecipeModal({super.key, required this.source, this.aiService});

  @override
  State<RemixRecipeModal> createState() => _RemixRecipeModalState();
}

class _RemixRecipeModalState extends State<RemixRecipeModal> {
  final _instructions = TextEditingController();
  late final AIInterface _aiService = widget.aiService ?? GeminiService();
  bool _isGenerating = false;
  String? _error;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_isGenerating) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final result = await _aiService.remixRecipe(
        source: widget.source,
        instructions: _instructions.text,
        languageCode: context.locale.languageCode,
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (result.success && result.recipe != null) {
        Navigator.pop(context, result.recipe);
      } else {
        setState(() => _error = result.error ?? 'remix_generation_error');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'remix_generation_error');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'remix'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'cancel'.tr(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                widget.source.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _instructions,
                enabled: !_isGenerating,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: 'remix_request'.tr(),
                  alignLabelWithHint: true,
                  hintText: 'remix_request_hint'.tr(),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    ['remix_vegetarian', 'remix_quicker', 'remix_surprise']
                        .map(
                          (key) => ActionChip(
                            label: Text(key.tr()),
                            onPressed: _isGenerating
                                ? null
                                : () {
                                    _instructions.text = '${key}_request'.tr();
                                  },
                          ),
                        )
                        .toList(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!.tr(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isGenerating ? null : _generate,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  (_isGenerating ? 'remix_generating' : 'remix_generate').tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
