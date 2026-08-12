import 'package:flutter/material.dart';

enum GMessageTone { neutral, success, warning, danger }

@immutable
class GMessage {
  const GMessage(
    this.text, {
    this.tone = GMessageTone.neutral,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(milliseconds: 3600),
  });

  const GMessage.success(
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) : this(
         text,
         tone: GMessageTone.success,
         actionLabel: actionLabel,
         onAction: onAction,
       );

  const GMessage.warning(
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) : this(
         text,
         tone: GMessageTone.warning,
         actionLabel: actionLabel,
         onAction: onAction,
       );

  const GMessage.danger(
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) : this(
         text,
         tone: GMessageTone.danger,
         actionLabel: actionLabel,
         onAction: onAction,
       );

  final String text;
  final GMessageTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
}
