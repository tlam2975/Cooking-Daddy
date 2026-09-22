import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Step;
import 'dart:math';
import 'dart:async';
import '../data/models/recipe.dart';
import '../data/repositories/recipe_repository.dart';
import 'package:flutter/services.dart';
import '../services/app_navigation_controller.dart';
import '../services/live_activity_service.dart';
import '../services/notification.dart';
import '../services/step_activity.dart';
import '../services/timer.dart';
import '../theme/app_theme.dart';
import '../widgets/recipe_image.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

class CookingSessionScreen extends StatefulWidget {
  final Recipe recipe;

  const CookingSessionScreen({super.key, required this.recipe});

  @override
  State<CookingSessionScreen> createState() => _CookingSessionScreenState();
}

class _CookingSessionScreenState extends State<CookingSessionScreen> {
  int currentStepIndex = 0;
  final TimerService _timerService = TimerService();
  final RecipeRepository _repository = RecipeRepository();
  final CookingLiveActivityService _liveActivity = CookingLiveActivityService();
  bool _completionRecorded = false;
  bool? _timerNotificationsEnabled;
  bool _timerWasRunning = false;
  bool _suppressTimerActivityUpdate = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_liveActivity.start(_liveActivitySnapshot()));
      }
    });
  }

  @override
  void dispose() {
    _suppressTimerActivityUpdate = true;
    unawaited(_liveActivity.end(_liveActivitySnapshot()));
    _timerService.removeListener(_onTimerUpdate);
    _timerService.dispose();
    _proximitySubscription?.cancel();
    _holdTimer?.cancel();
    _delayTimer?.cancel();
    super.dispose();
  }

  // ==================== TIMER METHODS ====================

  void _onTimerUpdate() {
    final runningChanged = _timerWasRunning != _timerService.isRunning;
    _timerWasRunning = _timerService.isRunning;
    if (runningChanged && !_suppressTimerActivityUpdate) {
      unawaited(_liveActivity.update(_liveActivitySnapshot()));
    }

    // Check if timer just finished (was running, now stopped at 0)
    if (!_timerService.isRunning && _timerService.remainingSeconds == 0) {
      // Timer finished! Activate proximity sensor
      if (!_proximityEnabled) {
        print('⏰ Timer finished - activating proximity sensor');
        _activateProximity();
      }
    }
  }

  Future<void> startTimer(int totalSeconds) async {
    print('Starting timer for $totalSeconds seconds');

    // Deactivate proximity while timer is running
    _deactivateProximity();
    _delayTimer?.cancel();

    final scheduleNotification = await _confirmTimerNotifications();
    if (!mounted) return;

    await _timerService.startTimer(
      seconds: totalSeconds,
      recipeName: widget.recipe.name,
      stepNumber: currentStepIndex + 1,
      scheduleNotification: scheduleNotification,
    );
    print('Timer service is running: ${_timerService.isRunning}');
  }

  Future<bool> _confirmTimerNotifications() async {
    if (_timerNotificationsEnabled != null) return _timerNotificationsEnabled!;
    if (NotificationService.timerPermissionRequested) {
      _timerNotificationsEnabled = true;
      return true;
    }

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('timer_notifications_title'.tr()),
        content: Text('timer_notifications_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('not_now'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('enable_notifications'.tr()),
          ),
        ],
      ),
    );

    if (shouldRequest != true) {
      _timerNotificationsEnabled = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('timer_notifications_skipped'.tr())),
        );
      }
      return false;
    }

    final granted = await NotificationService.requestTimerPermissions();
    _timerNotificationsEnabled = granted;
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('timer_notifications_denied'.tr())),
      );
    }
    return granted;
  }

  void stopTimer() {
    _timerService.stopTimer();
  }

  CookingLiveActivitySnapshot _liveActivitySnapshot() {
    final completed = currentStepIndex >= widget.recipe.steps.length;
    final step = completed ? null : widget.recipe.steps[currentStepIndex];
    final stepNumber = completed
        ? widget.recipe.steps.length
        : currentStepIndex + 1;

    return CookingLiveActivitySnapshot(
      recipeName: widget.recipe.name,
      stepIndex: stepNumber,
      totalSteps: widget.recipe.steps.length,
      instruction: completed ? 'done'.tr() : step!.instruction,
      activityType: StepActivityResolver.effective(step, completed: completed),
      timerEnd: _timerService.isRunning
          ? DateTime.now().add(
              Duration(seconds: _timerService.remainingSeconds),
            )
          : null,
      isCompleted: completed,
    );
  }

  void _exitCookingSession() {
    _suppressTimerActivityUpdate = true;
    stopTimer();
    unawaited(_liveActivity.end(_liveActivitySnapshot()));
    Navigator.pop(context);
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
    _suppressTimerActivityUpdate = true;
    stopTimer();
    _suppressTimerActivityUpdate = false;

    // Deactivate proximity
    _deactivateProximity();
    _delayTimer?.cancel();

    int? nextTimerSeconds;
    var shouldStartDelayedProximity = false;

    setState(() {
      if (currentStepIndex < widget.recipe.steps.length - 1) {
        currentStepIndex++;

        final nextStep = widget.recipe.steps[currentStepIndex];
        if (nextStep.timer != null && nextStep.timer! > 0) {
          nextTimerSeconds = nextStep.timer!;
        } else {
          shouldStartDelayedProximity = true;
        }
      } else {
        // Move to completion screen
        currentStepIndex = widget.recipe.steps.length;
        _recordCompletion();
      }
    });

    if (currentStepIndex >= widget.recipe.steps.length) {
      unawaited(_liveActivity.end(_liveActivitySnapshot()));
    } else {
      unawaited(_liveActivity.update(_liveActivitySnapshot()));
    }

    if (nextTimerSeconds != null) {
      startTimer(nextTimerSeconds!);
    } else if (shouldStartDelayedProximity) {
      _startDelayedProximity();
    }
  }

  Future<void> _recordCompletion() async {
    if (_completionRecorded) return;
    _completionRecorded = true;
    await _repository.recordCooked(widget.recipe);
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
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'back'.tr(),
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _exitCookingSession,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.recipe.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isLastStep
                                      ? 'done'.tr()
                                      : '${'step'.tr()} ${currentStepIndex + 1} / ${widget.recipe.steps.length}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _CookingActivityIcon(
                            step: currentStep,
                            completed: isLastStep,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: AppRadii.small,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: isLastStep
                              ? 1
                              : (currentStepIndex + 1) /
                                    widget.recipe.steps.length,
                          backgroundColor: AppColors.primaryLight,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          final offset = Tween<Offset>(
                            begin: const Offset(0.025, 0),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offset,
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(currentStepIndex),
                          child: isLastStep
                              ? _buildCompletionScreen()
                              : _buildStepScreen(currentStep!),
                        ),
                      ),

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
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.92,
                                ),
                                borderRadius: AppRadii.medium,
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
                                    'wave_to_continue'.tr(),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => RecipeImage(
              recipe: widget.recipe,
              width: constraints.maxWidth,
              height: 164,
              borderRadius: AppRadii.large,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${'step'.tr()} ${currentStepIndex + 1}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.instruction,
            style: AppTextStyles.greeting.copyWith(fontSize: 25, height: 1.35),
          ),
          const SizedBox(height: 24),

          if (step.heat != null && step.heat!.isNotEmpty) ...[
            _buildStepDetail(
              icon: Icons.local_fire_department_outlined,
              label: 'heat'.tr(),
              value: step.heat!,
            ),
            const SizedBox(height: 10),
          ],

          if (step.seasonings != null && step.seasonings!.isNotEmpty) ...[
            _buildStepDetail(
              icon: Icons.restaurant_outlined,
              label: 'seasonings'.tr(),
              value: step.seasonings!,
            ),
            const SizedBox(height: 10),
          ],

          if (hasTimer) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  AppColors.brandPink.withValues(alpha: 0.36),
                  AppColors.surface,
                ),
                borderRadius: AppRadii.large,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            value: _timerService.isRunning
                                ? _timerService.remainingSeconds / step.timer!
                                : 1,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        Text(
                          _timerService.isRunning
                              ? formatTime(_timerService.remainingSeconds)
                              : formatTime(step.timer!),
                          style: AppTextStyles.sectionTitle.copyWith(
                            fontSize: 21,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'timer'.tr(),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _timerService.isRunning
                              ? stopTimer
                              : () => startTimer(step.timer!),
                          icon: Icon(
                            _timerService.isRunning
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            _timerService.isRunning
                                ? 'stopTimer'.tr()
                                : 'startTimer'.tr(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (step.whatToLookFor.isNotEmpty) ...[
            _buildStepDetail(
              icon: Icons.visibility_outlined,
              label: 'until_it_is'.tr(),
              value: step.whatToLookFor,
              highlighted: true,
            ),
            const SizedBox(height: 10),
          ],

          if (step.notes != null && step.notes!.isNotEmpty) ...[
            _buildStepDetail(
              icon: Icons.sticky_note_2_outlined,
              label: 'notes'.tr(),
              value: step.notes!,
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: nextStep,
              icon: const Icon(Icons.arrow_forward),
              iconAlignment: IconAlignment.end,
              label: Text(
                'done'.tr(),
                style: AppTextStyles.cardTitle.copyWith(
                  color: Colors.white,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDetail({
    required IconData icon,
    required String label,
    required String value,
    bool highlighted = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryLight : AppColors.surface,
        borderRadius: AppRadii.medium,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 3),
                Text(value, style: AppTextStyles.body.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final titleSize = min(42.0, max(28.0, width * 0.11));
        final recipeSize = min(44.0, max(28.0, width * 0.12));

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: max(0, constraints.maxHeight - 48),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.brandPink,
                      borderRadius: AppRadii.large,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 36,
                      color: Color(0xFF4B272D),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'congratulations'.tr(),
                      maxLines: 1,
                      softWrap: false,
                      style: AppTextStyles.greeting.copyWith(
                        fontSize: titleSize,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'you_have_made'.tr(),
                    style: AppTextStyles.body.copyWith(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.recipe.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.greeting.copyWith(
                      fontSize: recipeSize,
                      height: 1.08,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        AppNavigationController.instance.selectDashboard();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: Text(
                        'back_to_home'.tr(),
                        style: AppTextStyles.cardTitle.copyWith(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CookingActivityIcon extends StatelessWidget {
  final Step? step;
  final bool completed;

  const _CookingActivityIcon({required this.step, required this.completed});

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.brandPink,
        borderRadius: AppRadii.medium,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          icon,
          key: ValueKey(icon),
          color: const Color(0xFF4B272D),
          size: 23,
        ),
      ),
    );
  }

  IconData get _icon {
    switch (StepActivityResolver.effective(step, completed: completed)) {
      case StepActivityType.prep:
        return Icons.soup_kitchen_outlined;
      case StepActivityType.chop:
        return Icons.content_cut_rounded;
      case StepActivityType.mix:
        return Icons.blender_outlined;
      case StepActivityType.heat:
        return Icons.local_fire_department_outlined;
      case StepActivityType.bake:
        return Icons.bakery_dining_outlined;
      case StepActivityType.wait:
        return Icons.hourglass_bottom_rounded;
      case StepActivityType.timer:
        return Icons.timer_outlined;
      case StepActivityType.plate:
        return Icons.room_service_outlined;
      case StepActivityType.complete:
        return Icons.check_rounded;
    }
  }
}
