import 'package:device_probe/device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../ui/g_card.dart';
import '../state/identity_providers.dart';
import '../../../core/i18n/g_strings.dart';

/// WHAT THIS PHONE IS.
///
/// Every field comes from [DeviceIdentity], which is read once per launch and
/// cached natively, so this page costs nothing to open.
///
/// ─── ABSENT MEANS ABSENT ─────────────────────────────────────────────────────
///
/// A row whose value is null is not rendered. Not greyed, not marked
/// unavailable, not explained: gone. That is the same rule the rest of the app
/// follows for nullable stats, and it means every line on this page is a fact
/// rather than a mixture of facts and apologies.
class SystemCard extends ConsumerWidget {
  const SystemCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeviceIdentity? identity = ref.watch(deviceIdentityProvider).value;
    if (identity == null) return const _Reading();

    return _Facts(
      rows: <(String, String?)>[
        ('Name', identity.marketingName),
        ('Manufacturer', identity.manufacturer),
        ('Model', identity.model),
        ('Android', identity.androidRelease),
        ('API level', '${identity.sdkInt}'),
        ('Interface', identity.skin),
        ('Security patch', identity.securityPatch),
        ('Build', identity.fingerprint),
      ],
    );
  }
}

/// WHAT THIS APP CAN REACH.
///
/// The most consequential thing on the Device tab and it has never been drawn.
/// [StorageAccess] has been in the probe since Phase 4 with no screen behind it,
/// which meant the one fact explaining why a scan found less than the user
/// expected was invisible.
class AccessCard extends ConsumerWidget {
  const AccessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StorageAccess? access = ref.watch(storageAccessProvider).value;
    if (access == null) return const _Reading();

    final GTokens t = context.g;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                access.allFilesAccessGranted ? 'Full access' : 'Limited access',
                style: GType.title.copyWith(
                  color: access.allFilesAccessGranted ? t.success : t.warning,
                ),
              ),
              const SizedBox(height: GSpace.sm),
              Text(
                access.allFilesAccessGranted
                    ? 'Trash folders, app leftovers and the thumbnail cache are '
                          'all reachable.'
                    : 'Only files this app created are reachable. Everything '
                          'your other apps left behind stays invisible.',
                style: GType.bodySmall.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: GSpace.md - 1),
        _Facts(
          rows: <(String, String?)>[
            ('Storage model', _tier(access.tier)),
            ('API level', '${access.sdkInt}'),
            ('System trash', _yesNo(access.osTrashBin)),
            ('All files access', _yesNo(access.allFilesAccessGranted)),
            (
              'Can be requested',
              access.allFilesAccessGranted
                  ? null
                  : _yesNo(access.allFilesAccessPossible),
            ),
          ],
        ),
      ],
    );
  }

  /// The tier as a phrase rather than the raw token. Native keeps a String so a
  /// fourth tier costs nothing; the screen should not show the token.
  static String _tier(String tier) {
    switch (tier) {
      case 'legacy':
        return 'Legacy, before scoped storage';
      case 'scoped':
        return 'Scoped storage';
      case 'managed':
        return 'Scoped, with manager access';
      default:
        return tier;
    }
  }

  static String _yesNo(bool value) => value ? 'Yes' : 'No';
}

/// Rows, minus the ones with nothing to say.
class _Facts extends StatelessWidget {
  const _Facts({required this.rows});

  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final List<(String, String)> present = <(String, String)>[
      for (final (String label, String? value) in rows)
        if (value != null && value.isNotEmpty) (label, value),
    ];
    if (present.isEmpty) return const SizedBox.shrink();

    return GCard(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.md),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < present.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: GSpace.md - 2),
              decoration: BoxDecoration(
                border: i == present.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: t.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    present[i].$1,
                    style: GType.body.copyWith(color: t.text),
                  ),
                  const SizedBox(width: GSpace.lg),
                  Expanded(
                    child: SelectableText(
                      present[i].$2,
                      textAlign: TextAlign.right,
                      // Selectable, because a build fingerprint exists to be
                      // pasted into a support message and retyping one by hand
                      // is how the wrong one ends up in a bug report.
                      style: GType.monoSmall.copyWith(color: t.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return GCard(
      child: Text(
        context.s('Reading'),
        style: GType.monoSmall.copyWith(color: t.dim),
      ),
    );
  }
}
