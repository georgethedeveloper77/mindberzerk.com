import 'package:flutter/widgets.dart';
import '../engine/theme_spec.dart';

/// Every desktop metaphor implements this.
/// Four of them cover every Linux distro worth shipping.
abstract class Shell extends StatelessWidget {
  const Shell({required this.spec, super.key});
  final ThemeSpec spec;
}
