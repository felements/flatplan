import 'package:flutter/material.dart';

/// A horizontal row of numbered steps: done ones show a check, the
/// current one is filled, later ones are outlined. Purely presentational;
/// the owner decides which step is current.
class WizardSteps extends StatelessWidget {
  final List<String> labels;

  /// Index into [labels] of the step the user is on.
  final int current;

  const WizardSteps({super.key, required this.labels, required this.current})
    : assert(labels.length > 0),
      assert(current >= 0 && current < labels.length);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i <= current ? colorScheme.primary : colorScheme.outlineVariant,
              ),
            ),
          _Step(
            number: i + 1,
            count: labels.length,
            label: labels[i],
            state: i < current
                ? _StepState.done
                : i == current
                ? _StepState.current
                : _StepState.upcoming,
          ),
        ],
      ],
    );
  }
}

enum _StepState { done, current, upcoming }

class _Step extends StatelessWidget {
  final int number;
  final int count;
  final String label;
  final _StepState state;

  const _Step({
    required this.number,
    required this.count,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final active = state != _StepState.upcoming;
    final fill = switch (state) {
      _StepState.done || _StepState.current => colorScheme.primary,
      _StepState.upcoming => Colors.transparent,
    };
    final ring = active ? colorScheme.primary : colorScheme.outlineVariant;
    final onFill = active ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final labelColor = switch (state) {
      _StepState.current => colorScheme.onSurface,
      _StepState.done => colorScheme.primary,
      _StepState.upcoming => colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    };

    return Semantics(
      label: 'Step $number of $count: $label',
      selected: state == _StepState.current,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 1.5),
            ),
            alignment: Alignment.center,
            child: state == _StepState.done
                ? Icon(Icons.check_rounded, size: 16, color: onFill)
                : Text(
                    '$number',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onFill,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: labelColor,
              fontWeight: state == _StepState.current ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
