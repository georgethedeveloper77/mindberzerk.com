import 'package:collection/collection.dart';

import 'theme_spec.dart' show ShellKind;

/// A fake Linux boot sequence, expressed as data.
///
/// This is the "geek out" feature: the scrolling `[  OK  ]` systemd spew a real
/// distro prints before it hands you a desktop. Because it is data, a distro
/// downloaded over the CDN ships its OWN boot log with no app update, exactly
/// like its palette and wallpaper do. Ubuntu flashes GRUB and starts snapd,
/// Arch spews the verbose kernel dmesg, Fedora does its own thing. The renderer
/// ([BootSequence]) is a dumb widget that walks this list.
///
/// Forward-compatible on purpose, matching the rest of the theme layer: an
/// unknown line `kind` from a newer CDN theme degrades to plain text rather
/// than throwing. A boot log from the future should look slightly wrong, never
/// crash the first thing the user sees.
///
/// Hand-rolled fromJson, no codegen, same as ThemeSpec.

/// How a single boot line is styled. The kind drives colour and default timing.
enum BootLineKind {
  /// `[  OK  ]` in green. The workhorse.
  ok,

  /// `[  **  ]` in the theme accent. A unit that hangs for a beat before it
  /// resolves. Sprinkle these in: uniform timing is what makes a fake boot look
  /// fake. Real logs are bursty.
  warn,

  /// `[FAILED]` in red. Use sparingly or never. A launcher that appears to fail
  /// a service on every boot reads as broken, not authentic.
  fail,

  /// Plain foreground text. Loader messages, login prompts.
  plain,

  /// Dimmed text. Kernel `dmesg` lines, timestamps, the quiet background noise.
  dim,

  /// The GRUB title bar flash (inverse block).
  grub,

  /// A selected GRUB menu row (highlighted block).
  grubSelected,

  /// An empty spacer line.
  blank;

  static BootLineKind parse(String? raw) {
    switch (raw) {
      case 'ok':
        return BootLineKind.ok;
      case 'warn':
        return BootLineKind.warn;
      case 'fail':
        return BootLineKind.fail;
      case 'dim':
        return BootLineKind.dim;
      case 'grub':
        return BootLineKind.grub;
      case 'grubSelected':
        return BootLineKind.grubSelected;
      case 'blank':
        return BootLineKind.blank;
      case 'plain':
      default:
        // Unknown kind from a newer theme degrades to plain. Never throw here.
        return BootLineKind.plain;
    }
  }
}

/// One line in the boot log.
class BootLine {
  const BootLine(this.kind, this.text, {this.delayMs});

  final BootLineKind kind;

  /// The message after the `[  OK  ]` tag. Ignored for blank lines.
  final String text;

  /// Pause BEFORE this line appears, in ms. Null means "use the default for
  /// this kind" (see [defaultDelayFor]). Author a value only when you want to
  /// deliberately break the rhythm, e.g. a long hang before the display
  /// manager comes up.
  final int? delayMs;

  int get effectiveDelayMs => delayMs ?? defaultDelayFor(kind);

  /// The rhythm. Fast bursts of OK, slower plain/dmesg, a beat for GRUB.
  static int defaultDelayFor(BootLineKind kind) {
    switch (kind) {
      case BootLineKind.ok:
        return 110;
      case BootLineKind.warn:
        return 300;
      case BootLineKind.fail:
        return 320;
      case BootLineKind.dim:
        return 170;
      case BootLineKind.plain:
        return 200;
      case BootLineKind.grub:
        return 380;
      case BootLineKind.grubSelected:
        return 520;
      case BootLineKind.blank:
        return 70;
    }
  }

  static BootLine fromJson(Map<String, dynamic> j) => BootLine(
        BootLineKind.parse(j['kind'] as String?),
        j['text'] as String? ?? '',
        delayMs: (j['delayMs'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is BootLine &&
      other.kind == kind &&
      other.text == text &&
      other.delayMs == delayMs;

  @override
  int get hashCode => Object.hash(kind, text, delayMs);
}

/// The full boot log for one theme.
class BootSpec {
  const BootSpec({
    required this.lines,
    this.tailMs = 600,
  });

  final List<BootLine> lines;

  /// How long to hold on the finished log before the shell is revealed. The
  /// little pause after "reached graphical target" sells the landing.
  final int tailMs;

  /// Roughly how long the whole thing runs, for callers that want to know
  /// (e.g. to decide whether it is worth showing at all on a fast repeat).
  int get totalMs =>
      lines.fold<int>(0, (sum, l) => sum + l.effectiveDelayMs) + tailMs;

  /// Forward-compatible parse. A theme with no `boot` block, or a malformed
  /// one, yields null and the caller falls back to [defaultForShell].
  static BootSpec? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final raw = j['lines'];
    if (raw is! List || raw.isEmpty) return null;
    final lines = <BootLine>[];
    for (final entry in raw) {
      if (entry is Map) {
        lines.add(BootLine.fromJson(entry.cast<String, dynamic>()));
      }
    }
    if (lines.isEmpty) return null;
    return BootSpec(
      lines: lines,
      tailMs: (j['tailMs'] as num?)?.toInt() ?? 600,
    );
  }

  /// Built-in boot logs keyed by SHELL, not by distro id.
  ///
  /// Keying by shell is deliberate and load-bearing. The moment this switched
  /// on `theme.id == 'fedora'` we would be back in the trap ThemeSpec exists to
  /// avoid. Per-distro flavour is the theme.json `boot` block's job; this is the
  /// sane family default when a theme ships without one. Ubuntu and Fedora
  /// (both gnome) share this default until either overrides it in data.
  static BootSpec defaultForShell(ShellKind shell) {
    switch (shell) {
      case ShellKind.gnome:
        return const BootSpec(lines: [
          BootLine(BootLineKind.grub, 'GNU GRUB  version 2.12'),
          BootLine(BootLineKind.grubSelected, '*GNU/Linux'),
          BootLine(BootLineKind.blank, ''),
          BootLine(BootLineKind.plain, 'Loading Linux 6.8.0-generic ...'),
          BootLine(BootLineKind.plain, 'Loading initial ramdisk ...'),
          BootLine(BootLineKind.blank, ''),
          BootLine(BootLineKind.ok, 'Started Load Kernel Modules'),
          BootLine(BootLineKind.ok, 'Mounted /boot/efi'),
          BootLine(BootLineKind.ok, 'Reached target Local File Systems'),
          BootLine(BootLineKind.ok, 'Started udev Kernel Device Manager'),
          BootLine(BootLineKind.ok, 'Started D-Bus System Message Bus'),
          BootLine(BootLineKind.ok, 'Started Network Manager'),
          BootLine(BootLineKind.warn, 'Starting Snap Daemon ...'),
          BootLine(BootLineKind.ok, 'Started Snap Daemon'),
          BootLine(BootLineKind.ok, 'Started GNOME Display Manager'),
          BootLine(BootLineKind.ok, 'Reached target Graphical Interface'),
        ]);

      case ShellKind.plasma:
        return const BootSpec(lines: [
          BootLine(BootLineKind.plain, 'Loading Linux ...'),
          BootLine(BootLineKind.plain, 'Loading initial ramdisk ...'),
          BootLine(BootLineKind.blank, ''),
          BootLine(BootLineKind.ok, 'Started Load Kernel Modules'),
          BootLine(BootLineKind.ok, 'Reached target Local File Systems'),
          BootLine(BootLineKind.ok, 'Started udev Kernel Device Manager'),
          BootLine(BootLineKind.ok, 'Started D-Bus System Message Bus'),
          BootLine(BootLineKind.ok, 'Started NetworkManager'),
          BootLine(BootLineKind.warn, 'Starting Simple Desktop Display Manager ...'),
          BootLine(BootLineKind.ok, 'Started Simple Desktop Display Manager'),
          BootLine(BootLineKind.ok, 'Reached target Graphical Interface'),
        ]);

      case ShellKind.tiling:
        return const BootSpec(lines: [
          BootLine(BootLineKind.plain, ':: running early hook [udev]'),
          BootLine(BootLineKind.plain, ':: running hook [keymap]'),
          BootLine(BootLineKind.plain, ':: mounting \'/dev/sda2\' on real root'),
          BootLine(BootLineKind.blank, ''),
          BootLine(BootLineKind.dim, '[    0.000000] Linux version 6.9.7-arch1-1'),
          BootLine(BootLineKind.dim, '[    0.412001] systemd[1]: systemd 256 running'),
          BootLine(BootLineKind.ok, 'Reached target Local Encrypted Volumes'),
          BootLine(BootLineKind.ok, 'Started Journal Service'),
          BootLine(BootLineKind.ok, 'Reached target System Initialization'),
          BootLine(BootLineKind.ok, 'Started D-Bus System Message Bus'),
          BootLine(BootLineKind.ok, 'Started NetworkManager'),
          BootLine(BootLineKind.ok, 'Started Hyprland session'),
          BootLine(BootLineKind.ok, 'Reached target Graphical Interface'),
        ]);

      // Cmd-V at the chime. A real thing you can do, which is exactly the kind
      // of detail this feature exists for — and the payoff line is DSMOS
      // ("Don't Steal Mac OS X"), which every Mac person who has ever booted
      // verbose recognises instantly.
      case ShellKind.aqua:
        return const BootSpec(
          tailMs: 650,
          lines: [
            BootLine(BootLineKind.dim, 'efiboot loaded from device: Acpi(APP0002,0)'),
            BootLine(BootLineKind.dim, 'boot file path: \\System\\Library\\CoreServices\\boot.efi'),
            BootLine(BootLineKind.blank, ''),
            BootLine(BootLineKind.plain, 'Darwin Kernel Version 24.5.0'),
            BootLine(BootLineKind.dim, 'AppleACPICPU: ProcessorId=1 LocalApicId=0 Enabled'),
            BootLine(BootLineKind.ok, 'AppleIntelCPUPowerManagement: initialization complete'),
            BootLine(BootLineKind.ok, 'Loaded AppleAHCIDiskDriver'),
            BootLine(BootLineKind.plain, 'BSD root: disk3s1s1, major 1, minor 13'),
            BootLine(BootLineKind.ok, 'apfs: mounted Macintosh HD on device root_device'),
            BootLine(BootLineKind.warn, 'Waiting for DSMOS ...', delayMs: 620),
            BootLine(BootLineKind.ok, 'DSMOS has arrived'),
            BootLine(BootLineKind.ok, 'Started WindowServer'),
            BootLine(BootLineKind.ok, 'Started loginwindow'),
          ],
        );

      case ShellKind.tui:
        return const BootSpec(
          tailMs: 500,
          lines: [
            BootLine(BootLineKind.dim, '[    0.000000] booting g_launcher tty ...'),
            BootLine(BootLineKind.ok, 'mounted /proc /sys /dev'),
            BootLine(BootLineKind.ok, 'started device stats collector'),
            BootLine(BootLineKind.ok, 'started battery monitor'),
            BootLine(BootLineKind.ok, 'loaded UbuntuMono glyphs'),
            BootLine(BootLineKind.ok, 'reached target multi-user'),
            BootLine(BootLineKind.blank, ''),
            BootLine(BootLineKind.plain, 'g-tty login: user (automatic)'),
          ],
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BootSpec &&
      other.tailMs == tailMs &&
      const ListEquality<BootLine>().equals(other.lines, lines);

  @override
  int get hashCode =>
      Object.hash(tailMs, const ListEquality<BootLine>().hash(lines));
}
