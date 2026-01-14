import 'package:flutter/material.dart';

class RecipeEditorScreen extends StatefulWidget {
  const RecipeEditorScreen({super.key});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _toolsController = TextEditingController();

  List<StepData> steps = [StepData()]; // Start with one step
  String selectedCategory = 'Category';

  // Separated categories list - can be replaced with database data later
  final List<String> categories = [
    'Homecook',
    'Lazy meals',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Dessert',
  ];

  @override
  void dispose() {
    _urlController.dispose();
    _ingredientsController.dispose();
    _toolsController.dispose();
    for (var step in steps) {
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
        steps[index].dispose();
        steps.removeAt(index);
      });
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
                  // Title - CENTERED
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Add a recipe',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            color: const Color.fromARGB(255, 255, 230, 0),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gordon Ramsey?',
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
                        onPressed: () {
                          // AI generation logic here
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
                        child: const Text('Generate with AI'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ingredients Field
                    _buildTextField('Ingredients', _ingredientsController),
                    const SizedBox(height: 16),

                    // Tools Field
                    _buildTextField('Tools', _toolsController),
                    const SizedBox(height: 24),

                    // Steps
                    ...List.generate(steps.length, (index) {
                      return _buildStepCard(index);
                    }),

                    const SizedBox(height: 120), // Space for sticky bottom bar
                  ],
                ),
              ),
            ),
            // Sticky Bottom Bar
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add Step and Category Row
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
                          child: const Text(
                            'Add step',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        // Category Dropdown
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
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontFamily: 'PixelifySans',
                            ),
                            items: categories.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedCategory = newValue!;
                              });
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
                        onPressed: () {
                          // Save recipe logic here
                          Navigator.pop(context);
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
                        child: const Text(
                          'Done!',
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

  Widget _buildTextField(String label, TextEditingController controller) {
    return Row(
      children: [
        Text('$label:', style: const TextStyle(fontSize: 18)),
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

  Widget _buildStepCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${index + 1}',
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
          _buildStepField('Instruction', steps[index].instructionController),
          const SizedBox(height: 8),
          _buildStepField('Heat', steps[index].heatController),
          const SizedBox(height: 8),
          _buildStepField('Seasonings', steps[index].seasoningsController),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Timer:', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 16),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: steps[index].timerMinController,
                  keyboardType: TextInputType.number,
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
          _buildStepField('Notes', steps[index].notesController),
          const SizedBox(height: 8),
          _buildStepField('What to look for', steps[index].lookForController),
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
}

// Helper class to manage step data
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
