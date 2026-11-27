import 'package:flutter/material.dart';

/// A rounded square holding an icon, tinted with [color].
///
/// In dark mode the tone is lightened so the icon stays legible on dark
/// surfaces; the base colors are tuned for light backgrounds.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// The color actually painted for [brightness].
  Color toneFor(Brightness brightness) => brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, 0.35)!
      : color;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.withAlpha(34),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: tone, size: size * 0.55),
    );
  }
}
