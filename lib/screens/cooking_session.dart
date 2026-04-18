import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Step;
import 'dart:math';
import 'dart:async';
import '../data/models/recipe.dart';
import '../data/models/quotes.dart';
import 'package:flutter/services.dart';
import '../services/timer.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

class CookingSessionScreen extends StatefulWidget {
  final Recipe recipe;

  const CookingSessionScreen({super.key, required this.recipe});

  @override
  State<CookingSessionScreen> createState() => _CookingSessionScreenState();
}

class _CookingSessionScreenState extends State<CookingSessionScreen> {
  late String randomQuote;
  int currentStepIndex = 0;
  final TimerService _timerService = TimerService();

  // Proximity sensor variables
  StreamSubscription<int>? _proximitySubscription;
  Timer? _holdTimer;
  Timer? _delayTimer;
  double _holdProgress = 0.0;
  bool _proximityEnabled = false;
  bool _showProximityHint = false;

  @override
  void initState() {
    super.initState();

    // Initialize random quote
    randomQuote = cookingQuotes[Random().nextInt(cookingQuotes.length)];

    // Initialize proximity sensor
    _initProximitySensor();

    // Listen to timer updates
    _timerService.addListener(_onTimerUpdate);

    // Check if current step has timer
    final currentStep = widget.recipe.steps[currentStepIndex];
    if (currentStep.timer == null || currentStep.timer! <= 0) {
      // No timer - start 10-second delay
      _startDelayedProximity();
    }
  }

  @override
  void dispose() {
    _timerService.removeListener(_onTimerUpdate);
    _proximitySubscription?.cancel();
    _holdTimer?.cancel();
    _delayTimer?.cancel();
    super.dispose();
  }

  // ==================== TIMER METHODS ====================

  void _onTimerUpdate() {
    // Check if timer just finished (was running, now stopped at 0)
    if (!_timerService.isRunning && _timerService.remainingSeconds == 0) {
      // Timer finished! Activate proximity sensor
      if (!_proximityEnabled) {
        print('⏰ Timer finished - activating proximity sensor');
        _activateProximity();
      }
    }
  }

  void startTimer(int totalSeconds) {
    print('Starting timer for $totalSeconds seconds');

    // Deactivate proximity while timer is running
    _deactivateProximity();
    _delayTimer?.cancel();

    _timerService.startTimer(
      seconds: totalSeconds,
      recipeName: widget.recipe.name,
      stepNumber: currentStepIndex + 1,
    );
    print('Timer service is running: ${_timerService.isRunning}');
  }

  void stopTimer() {
    _timerService.stopTimer();
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ==================== PROXIMITY SENSOR ====================

  void _initProximitySensor() {
    _proximitySubscription = ProximitySensor.events.listen((int event) {
      // event: 0 = far, 1-100 = near (distance varies by device)
      if (_proximityEnabled && event > 0) {
        // Hand is near
        _onProximityNear();
      } else {
        _onProximityFar();
      }
    });
  }

  void _onProximityNear() {
    if (_holdTimer != null) return; // Already counting

    setState(() => _showProximityHint = true);

    // Start 2-second countdown with visual feedback
    _holdTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
      setState(() {
        _holdProgress += 0.025; // 50ms / 2000ms = 0.025

        if (_holdProgress >= 1.0) {
          // Hold completed - advance step!
          HapticFeedback.mediumImpact();
          nextStep();
          _resetProximity();
        }
      });
    });
  }

  void _onProximityFar() {
    _resetProximity();
  }

  void _resetProximity() {
    _holdTimer?.cancel();
    _holdTimer = null;
    setState(() {
      _holdProgress = 0.0;
      _showProximityHint = false;
    });
  }

  void _activateProximity() {
    setState(() {
      _proximityEnabled = true;
      _showProximityHint = true;
    });
  }

  void _deactivateProximity() {
    _resetProximity();
    setState(() => _proximityEnabled = false);
  }

  void _startDelayedProximity() {
    // For non-timer steps: activate after 10 seconds
    _delayTimer?.cancel();
    _delayTimer = Timer(Duration(seconds: 10), () {
      if (mounted && !_proximityEnabled) {
        _activateProximity();
      }
    });
  }

  // ==================== NAVIGATION ====================

  void nextStep() {
    stopTimer();

    // Deactivate proximity
    _deactivateProximity();
    _delayTimer?.cancel();

    setState(() {
      if (currentStepIndex < widget.recipe.steps.length - 1) {
        currentStepIndex++;

        // Auto-start timer if next step has one
        final nextStep = widget.recipe.steps[currentStepIndex];
        if (nextStep.timer != null && nextStep.timer! > 0) {
          startTimer(nextStep.timer!);
        } else {
          // No timer - start 10-second delay
          _startDelayedProximity();
        }
      } else {
        // Move to completion screen
        currentStepIndex = widget.recipe.steps.length;
      }
    });
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _timerService,
      builder: (context, child) {
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
                // Content with proximity overlay
                Expanded(
                  child: Stack(
                    children: [
                      // Main content
                      isLastStep
                          ? _buildCompletionScreen()
                          : _buildStepScreen(currentStep!),

                      // Proximity hint overlay
                      if (_proximityEnabled && _showProximityHint)
                        Positioned(
                          top: 20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pan_tool,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '👋 Wave hand to continue',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  // Progress bar
                                  Container(
                                    width: 200,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _holdProgress,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${(2 - _holdProgress * 2).toStringAsFixed(1)}s',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
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
                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'copyright'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== UI COMPONENTS ====================

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
                      Text(
                        'heat'.tr(),
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
                      Text(
                        'seasonings'.tr(),
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
            Text(
              'timer'.tr(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _timerService.isRunning
                    ? formatTime(_timerService.remainingSeconds)
                    : formatTime(step.timer!),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_timerService.isRunning)
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
                child: Text('startTimer'.tr()),
              ),
            if (_timerService.isRunning)
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
                child: Text('stopTimer'.tr()),
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
                        Text(
                          'until_it_is'.tr(),
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
                        Text(
                          'notes'.tr(),
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
              child: Text(
                'done'.tr(),
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
            Text(
              'congratulations'.tr(),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'you_have_made'.tr(),
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            Text(
              widget.recipe.name,
              style: const TextStyle(
                fontSize: 60,
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
                child: Text(
                  'back_to_home'.tr(),
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
