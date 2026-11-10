import 'package:flutter/material.dart';

import '../logic/payment_tags.dart';

/// A payment `#tag` drawn as a small teal pill, without the `#`.
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teal = theme.colorScheme.secondary;
    // Plain teal on its own tint is under 4.5:1; shift the text toward the
    // surface's text colour so it stays readable in both themes.
    final ink = Color.alphaBlend(
      (theme.brightness == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: 0.28),
      teal,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A payment comment with its tags cut out of the text and drawn as chips
/// after it, in the order they were written.
class TaggedComment extends StatelessWidget {
  const TaggedComment(this.description, {super.key, this.style});

  final String? description;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final parsed = splitTags(description);
    if (parsed.tags.isEmpty) {
      return Text(
        parsed.text.isEmpty ? 'No comment' : parsed.text,
        style: style,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (parsed.text.isNotEmpty) Text(parsed.text, style: style),
        for (final tag in parsed.tags) TagChip(tag),
      ],
    );
  }
}
