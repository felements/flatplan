import 'package:flutter/material.dart';

/// The placeholder for a project without a readable avatar: the name's
/// initial on the theme's primary container.
class ProjectInitial extends StatelessWidget {
  final String name;
  final double size;

  const ProjectInitial({super.key, required this.name, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}
