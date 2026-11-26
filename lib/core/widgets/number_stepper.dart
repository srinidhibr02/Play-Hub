import 'package:flutter/material.dart';

/// A label with minus / plus buttons around a value, for small numeric rules.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.suffix = '',
    this.helper,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrease = value - step >= min;
    final canIncrease = value + step <= max;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (helper != null)
                Text(
                  helper!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: canDecrease ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 64,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '$value$suffix',
              key: ValueKey(value),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: canIncrease ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
