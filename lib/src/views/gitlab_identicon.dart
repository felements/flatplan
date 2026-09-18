import 'package:flutter/material.dart';

/// What GitLab shows for a project without an uploaded avatar: the name's
/// initial on a pastel picked by project id, so the row looks like the
/// project page the user knows.
class GitLabIdenticon extends StatelessWidget {
  /// GitLab's identicon backgrounds, indexed by `id % 7`.
  static const palette = [
    Color(0xFFFCF1EF),
    Color(0xFFF4F0FF),
    Color(0xFFF1F1FF),
    Color(0xFFE9F3FC),
    Color(0xFFECF4EE),
    Color(0xFFFDF1DD),
    Color(0xFFF0F0F0),
  ];

  static Color colorFor(int id) => palette[id % palette.length];

  final int id;
  final String name;
  final double size;

  const GitLabIdenticon({
    super.key,
    required this.id,
    required this.name,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorFor(id),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: const Color(0xFF3A383F),
          fontWeight: FontWeight.w600,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}
