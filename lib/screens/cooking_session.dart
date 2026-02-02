import 'package:flutter/material.dart' hide Step;
import 'dart:math';
import 'dart:async';
import '../data/models/recipe.dart';
import '../data/models/quotes.dart';
import '../services/notification.dart';
// import 'package:vibration/vibration.dart';
// import 'package:flutter_haptic_feedback/flutter_haptic_feedback.dart';
import 'package:flutter/services.dart';

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
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
          print('Timer: $remainingSeconds seconds remaining');
        } else {
          print('Timer: Reached zero! Calling _onTimerComplete');
          t.cancel();
          timerRunning = false;
          _onTimerComplete();
        }
      });
    });
  }

  Future<void> _onTimerComplete() async {
    try {
      // Haptic feedback for iOS
      for (int i = 0; i < 10; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 400));
        await HapticFeedback.heavyImpact();
      }
      // Notification
      await NotificationService.showTimerCompleteNotification(
        title: 'Timer Done! ⏰',
        body:
            'Step ${currentStepIndex + 1} for ${widget.recipe.name} is ready. \nComeback right now!',
      );

      // Visual feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏰ Timer done! Check Step ${currentStepIndex + 1}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error in _onTimerComplete: $e');
    }
  }

  //===============V2 of _onTimerComplete - Added sound alarm=============================

  // Future<void> _onTimerComplete() async {
  //   try {
  //     // Check if app is in foreground or background
  //     if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
  //       // APP IS OPEN - play alarm + STRONG vibration

  //       // Play alarm sound
  //       await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));

  //       // STRONG vibration pattern - like phone calls
  //       // Vibrate continuously for 3 seconds
  //       for (int i = 0; i < 6; i++) {
  //         await HapticFeedback.heavyImpact();
  //         await Future.delayed(const Duration(milliseconds: 100));
  //         await HapticFeedback.heavyImpact();
  //         await Future.delayed(const Duration(milliseconds: 400));
  //       }

  //       // Visual feedback
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('⏰ Timer done! Check Step ${currentStepIndex + 1}'),
  //             backgroundColor: Colors.green,
  //             duration: const Duration(seconds: 5),
  //           ),
  //         );
  //       }
  //     } else {
  //       // APP IS IN BACKGROUND - send notification
  //       await NotificationService.showTimerCompleteNotification(
  //         title: 'Timer Done! ⏰',
  //         body:
  //             'Step ${currentStepIndex + 1} for ${widget.recipe.name} is ready',
  //       );
  //     }
  //   } catch (e) {
  //     print('Error in _onTimerComplete: $e');
  //   }
  // }

  //==========================================

  void stopTimer() {
    timer?.cancel();
    setState(() {
      timerRunning = false;
    });
  }

  void nextStep() {
    stopTimer();
    setState(() {
      if (currentStepIndex < widget.recipe.steps.length - 1) {
        currentStepIndex++;
        // Auto-start timer if next step has one
        final nextStep = widget.recipe.steps[currentStepIndex];
        if (nextStep.timer != null && nextStep.timer! > 0) {
          startTimer(nextStep.timer!);
        }
      } else {
        // Move to completion screen
        currentStepIndex =
            widget.recipe.steps.length; // This triggers isLastStep
      }
    });
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
                        const Text(
                          'Cooking Daddy',
                          style: TextStyle(
                            fontSize: 40,
                            color: Color.fromARGB(255, 255, 230, 0),
                          ),
                        ),
                        Text(
                          randomQuote,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
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

          // Heat
          if (step.heat != null && step.heat!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFA4A4), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.red),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Heat',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        step.heat!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Seasonings
          if (step.seasonings != null && step.seasonings!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFA4A4), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.restaurant, color: Colors.brown),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seasonings',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        step.seasonings!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Timer
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
            const SizedBox(height: 32),
          ],

          // What to look for
          if (step.whatToLookFor.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE082), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.visibility, color: Color(0xFFFFA726)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Until it is:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          step.whatToLookFor,
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Notes
          if (step.notes != null && step.notes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, color: Color(0xFF42A5F5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          step.notes!,
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 40),
            const Text(
              'Congratulations!!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 255, 231, 11),
              ),
              textAlign: TextAlign.center,
              // ,
            ),
            const Text(
              'You have just made:',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            Text(
              widget.recipe.name,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 255, 58, 58),
              ),
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
