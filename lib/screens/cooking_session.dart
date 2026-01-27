import 'package:flutter/material.dart' hide Step;
import 'dart:math';
import 'dart:async';
import '../data/models/recipe.dart';
import '../data/models/quotes.dart';

class CookingSessionScreen extends StatefulWidget {
  final Recipe recipe;

  const CookingSessionScreen({super.key, required this.recipe});

  @override
  State<CookingSessionScreen> createState() => _CookingSessionScreenState();
}

class _CookingSessionScreenState extends State<CookingSessionScreen> {
  late String randomQuote;
  int currentStepIndex = 0;

  // Timer variables
  Timer? timer;
  int remainingSeconds = 0;
  bool timerRunning = false;

  // final List<String> quotes = [
  //   'just like how ur mom makes it',
  //   'oui chef!',
  //   'cause dads can cook too',
  //   'fuiyoooooooo',
  //   "haiyaaa don't mess it up",
  //   'about to be an influencer',
  // ];

  @override
  void initState() {
    super.initState();
    randomQuote = cookingQuotes[Random().nextInt(cookingQuotes.length)];
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startTimer(int totalSeconds) {
    setState(() {
      remainingSeconds = totalSeconds;
      timerRunning = true;
    });

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else {
          t.cancel();
          timerRunning = false;
        }
      });
    });
  }

  void stopTimer() {
    timer?.cancel();
    setState(() {
      timerRunning = false;
    });
  }

  void nextStep() {
    stopTimer();
    if (currentStepIndex < widget.recipe.steps.length - 1) {
      setState(() {
        currentStepIndex++;
        // Auto-start timer if next step has one
        final nextStep = widget.recipe.steps[currentStepIndex];
        if (nextStep.timer != null && nextStep.timer! > 0) {
          startTimer(nextStep.timer!);
        }
      });
    }
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = currentStepIndex >= widget.recipe.steps.length;
    final currentStep = isLastStep
        ? null
        : widget.recipe.steps[currentStepIndex];

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
                      onPressed: () {
                        stopTimer();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  // Title
                  Center(
                    child: Column(
                      children: [
                        Text(
                          randomQuote,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            color: const Color.fromARGB(255, 255, 230, 0),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cooking Daddy',
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
              child: isLastStep
                  ? _buildCompletionScreen()
                  : _buildStepScreen(currentStep!),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '©2026 Tung Lam created',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepScreen(Step step) {
    final hasTimer = step.timer != null && step.timer! > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Recipe Name
          Text(
            widget.recipe.name,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Step Instruction
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              step.instruction,
              style: const TextStyle(fontSize: 20, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Timer (if available)
          if (hasTimer) ...[
            const Text(
              'Timer',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                timerRunning
                    ? formatTime(remainingSeconds)
                    : formatTime(step.timer!),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!timerRunning)
                  ElevatedButton(
                    onPressed: () => startTimer(step.timer!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA4A4),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Start Timer'),
                  ),
                if (timerRunning)
                  ElevatedButton(
                    onPressed: stopTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Stop Timer'),
                  ),
              ],
            ),
            const SizedBox(height: 32),
          ],

          // "Until it is" section
          if (step.whatToLookFor.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Until it is:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.whatToLookFor,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Done Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB8E6F5),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.recipe.name,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Congratulations!!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'You have just made:',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB8E6F5),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
