/// `apt`, `pacman`, `dnf` and friends, mapped onto the package manager this
/// phone actually has: Google Play.
///
/// Each manager keeps its own grammar (`pacman -S`, `apt install`, `dnf
/// remove`) and its own output voice, because the first thing an Arch user
/// does at a new prompt is type `pacman -Syu` and judge the answer. What
/// happens is always real and always the same handful of things: a Play
/// search, Play's updates page, the system uninstall prompt, or a list.
///
/// Nothing installs silently. A launcher cannot, and pretending to would be
/// the one lie this terminal does not tell: `install` opens Play on the
/// search and says so.
library;

import '../../data/search/search_text.dart';

/// What the screen does after printing [PackagePlan.lines].
sealed class PackageEffect {
  const PackageEffect();
}

class PlaySearch extends PackageEffect {
  const PlaySearch(this.query);
  final String query;

  String get url =>
      'market://search?q=${Uri.encodeQueryComponent(query)}&c=apps';
}

class PlayUpdates extends PackageEffect {
  const PlayUpdates();
}

class Uninstall extends PackageEffect {
  const Uninstall(this.componentKey);
  final String componentKey;
}

class NoEffect extends PackageEffect {
  const NoEffect();
}

/// One installed app, as much of it as this needs.
class PackageApp {
  const PackageApp({
    required this.label,
    required this.packageName,
    required this.componentKey,
  });

  final String label;
  final String packageName;
  final String componentKey;
}

class PackagePlan {
  const PackagePlan(this.lines, [this.effect = const NoEffect()]);

  final List<String> lines;
  final PackageEffect effect;
}

enum _Verb { install, search, remove, upgrade, list, help }

abstract final class PackageCommands {
  /// Every name this answers to. The Terminal app routes these here.
  static const managers = <String>[
    'apt',
    'apt-get',
    'pacman',
    'yay',
    'paru',
    'dnf',
    'zypper',
    'pkg',
    'flatpak',
    'snap',
  ];

  static const _dim = '\x1b[90m';
  static const _green = '\x1b[32m';
  static const _bold = '\x1b[1m';
  static const _yellow = '\x1b[33m';
  static const _reset = '\x1b[0m';

  static PackagePlan run(
    String manager,
    String args,
    List<PackageApp> installed, {
    required bool sudo,
  }) {
    final words =
        args.trim().isEmpty ? <String>[] : args.trim().split(RegExp(r'\s+'));
    final (verb, terms) = _parse(manager, words);
    final term = terms.join(' ');

    switch (verb) {
      case _Verb.help:
        return PackagePlan(_usage(manager));

      case _Verb.list:
        final sorted = [...installed]..sort(
            (a, b) =>
                SearchText.fold(a.label).compareTo(SearchText.fold(b.label)),
          );
        return PackagePlan([
          if (manager == 'apt' || manager == 'apt-get') 'Listing... Done',
          for (final a in sorted)
            '$_green${a.packageName}$_reset $_dim${a.label}$_reset',
        ]);

      case _Verb.upgrade:
        return PackagePlan([
          ..._upgradeVoice(manager),
          '${_dim}opening Play Store updates$_reset',
        ], const PlayUpdates());

      case _Verb.search:
        if (term.isEmpty) return PackagePlan(['$manager: give a search term']);
        final local = _matches(installed, term);
        return PackagePlan([
          if (manager.startsWith('apt')) 'Sorting... Done',
          if (manager.startsWith('apt')) 'Full Text Search... Done',
          for (final a in local.take(5))
            '$_green${a.packageName}$_reset $_dim[installed]$_reset ${a.label}',
          '${_dim}searching Play Store for "$term"$_reset',
        ], PlaySearch(term));

      case _Verb.install:
        if (term.isEmpty) {
          return PackagePlan(['$manager: give a package name']);
        }
        final have = _exact(installed, term);
        if (have != null) {
          return PackagePlan([
            ..._readingVoice(manager),
            '${have.packageName} is already the newest version (${have.label}).',
            '0 upgraded, 0 newly installed, 0 to remove.',
          ]);
        }
        return PackagePlan([
          ..._readingVoice(manager),
          if (manager.startsWith('apt')) ...[
            'The following NEW packages will be installed:',
            '  $_bold$term$_reset',
          ] else
            '${_bold}Packages (1)$_reset $term',
          '${_dim}a phone installs through Play. opening it on "$term"$_reset',
        ], PlaySearch(term));

      case _Verb.remove:
        if (term.isEmpty) {
          return PackagePlan(['$manager: give a package name']);
        }
        final loose = _matches(installed, term);
        final app =
            _exact(installed, term) ?? (loose.isEmpty ? null : loose.first);
        if (app == null) {
          return PackagePlan([
            manager.startsWith('apt')
                ? 'E: Unable to locate package $term'
                : 'error: target not found: $term',
          ]);
        }
        return PackagePlan([
          if (!sudo && manager.startsWith('apt'))
            '${_yellow}W: removing as the phone owner, no sudo needed here$_reset',
          'Removing ${app.packageName} (${app.label})',
          '${_dim}opening the system uninstall prompt$_reset',
        ], Uninstall(app.componentKey));
    }
  }

  /// Turns each manager's own grammar into one verb.
  static (_Verb, List<String>) _parse(String manager, List<String> w) {
    if (w.isEmpty) return (_Verb.help, const []);
    final first = w.first;
    final rest = w.skip(1).where((x) => !x.startsWith('-')).toList();

    // pacman, yay, paru: flags ARE the verb.
    if (manager == 'pacman' || manager == 'yay' || manager == 'paru') {
      if (!first.startsWith('-')) {
        // `yay telegram` is a search-then-install in yay; treat as search.
        return (_Verb.search, w);
      }
      final f = first.substring(1);
      if (f.startsWith('S')) {
        if (f.contains('s')) return (_Verb.search, rest);
        if (f.contains('y') || f.contains('u')) {
          return rest.isEmpty ? (_Verb.upgrade, rest) : (_Verb.install, rest);
        }
        return (_Verb.install, rest);
      }
      if (f.startsWith('R')) return (_Verb.remove, rest);
      if (f.startsWith('Q')) return (_Verb.list, rest);
      return (_Verb.help, const []);
    }

    final verb = switch (first) {
      'install' || 'in' || 'add' || 'i' => _Verb.install,
      'search' || 'se' || 'find' || 'info' || 'show' => _Verb.search,
      'remove' ||
      'rm' ||
      'purge' ||
      'uninstall' ||
      'erase' ||
      'autoremove' =>
        _Verb.remove,
      'update' ||
      'upgrade' ||
      'up' ||
      'refresh' ||
      'dist-upgrade' ||
      'full-upgrade' ||
      'dup' =>
        _Verb.upgrade,
      'list' || 'ls' => _Verb.list,
      _ => _Verb.help,
    };
    return (verb, rest);
  }

  static PackageApp? _exact(List<PackageApp> apps, String term) {
    for (final a in apps) {
      if (SearchText.sameName(a.label, term) ||
          a.packageName.toLowerCase() == term.toLowerCase()) {
        return a;
      }
    }
    return null;
  }

  static List<PackageApp> _matches(List<PackageApp> apps, String term) => [
        for (final a in apps)
          if (SearchText.contains(a.label, term) ||
              a.packageName.toLowerCase().contains(term.toLowerCase()))
            a,
      ];

  static List<String> _readingVoice(String m) => switch (m) {
        'apt' || 'apt-get' => const [
            'Reading package lists... Done',
            'Building dependency tree... Done',
          ],
        'pacman' || 'yay' || 'paru' => const ['resolving dependencies...'],
        'dnf' => const ['Last metadata expiration check: just now.'],
        'zypper' => const [
            'Loading repository data...',
            'Reading installed packages...'
          ],
        _ => const [],
      };

  static List<String> _upgradeVoice(String m) => switch (m) {
        'pacman' || 'yay' || 'paru' => const [
            ':: Synchronizing package databases...',
            ' core is up to date',
            ' extra is up to date',
            ':: Starting full system upgrade...',
          ],
        'apt' || 'apt-get' => const [
            'Hit:1 https://play.google.com stable InRelease',
            'Reading package lists... Done',
          ],
        'dnf' => const ['Dependencies resolved.'],
        'flatpak' => const ['Looking for updates...'],
        'snap' => const ['All snaps up to date? Asking Play.'],
        _ => const ['Checking for updates...'],
      };

  static List<String> _usage(String m) {
    final pac = m == 'pacman' || m == 'yay' || m == 'paru';
    return [
      '${_bold}usage$_reset',
      pac
          ? '  $m -S <app>     install, via Play'
          : '  $m install <app>   install, via Play',
      pac ? '  $m -Ss <app>    search' : '  $m search <app>    search',
      pac ? '  $m -R <app>     remove' : '  $m remove <app>    remove',
      pac
          ? '  $m -Syu         update everything'
          : '  $m upgrade         update everything',
      pac
          ? '  $m -Q           list installed'
          : '  $m list            list installed',
    ];
  }
}
