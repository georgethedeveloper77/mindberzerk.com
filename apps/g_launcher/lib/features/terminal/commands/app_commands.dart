/// The `/apps` verbs that are not file verbs.
///
/// `ls /apps` and `cat /apps/firefox` already cover browsing and detail, so
/// what is left here is the launcher's own vocabulary: the flat list, the
/// package tools, and resolving a word.
library;

import '../term_command.dart';
import '../term_host.dart';
import '../term_output.dart';
import '../term_registry.dart';

class AppsCommand extends TermCommand {
  const AppsCommand();

  @override
  String get name => 'apps';
  @override
  TermGroup get group => TermGroup.apps;
  @override
  String get help => 'every app you can launch';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final List<TermApp> apps = await inv.context.host.apps();
    if (apps.isEmpty) return TermResult.line('no apps readable', TermInk.dim);

    // EVERY app. A filter downstream has to see all of them or it answers for
    // a list the user never asked about.
    return TermResult.lines(<TermLine>[
      for (final TermApp app in apps)
        TermLine(<TermSpan>[
          TermSpan(app.label.padRight(22)),
          TermSpan(app.packageName, TermInk.dim),
        ]),
    ]);
  }
}

class PmCommand extends TermCommand {
  const PmCommand();

  @override
  String get name => 'pm';
  @override
  TermGroup get group => TermGroup.apps;
  @override
  String get help => 'pm info, pm uninstall, pm settings';
  @override
  String? get usage => 'pm info|uninstall|settings <app>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final String sub = inv.positionals.isEmpty ? 'list' : inv.positionals.first;
    final String query = inv.positionals.skip(1).join(' ');

    if (sub == 'list') return const AppsCommand().run(inv);

    if (query.isEmpty) return missing('an app name');
    final TermApp? app = await inv.context.vfs.appNamed(query);
    if (app == null) {
      return TermResult.lines(<TermLine>[
        TermLine.of('pm: no app matches $query', TermInk.bad),
        TermLine.of('ls /apps lists them', TermInk.dim),
      ]);
    }

    switch (sub) {
      case 'info':
        return TermResult.lines(<TermLine>[
          TermLine.pair('label', app.label),
          TermLine.pair('package', app.packageName),
          if (app.sizeBytes != null)
            TermLine.pair('size', humanBytes(app.sizeBytes!)),
          if (app.targetSdk != null)
            TermLine.pair('target', 'SDK ${app.targetSdk}'),
        ]);
      case 'uninstall':
        {
          final String? refusal = await inv.context.host.requestUninstall(app);
          if (refusal != null) {
            return TermResult.error('pm: ${app.label}: $refusal');
          }
          // Says what it DID, which is fire the system prompt. It does not
          // claim the app was removed, because the shell will not be told.
          return TermResult.line(
            'opened the system uninstall prompt for ${app.label}',
            TermInk.dim,
          );
        }
      case 'settings':
        await inv.context.host.openAppSettings(app);
        return TermResult.line('opening app info for ${app.label}', TermInk.dim);
      default:
        return TermResult.lines(<TermLine>[
          TermLine.of('pm: unknown subcommand $sub', TermInk.bad),
          TermLine.of('info, uninstall, settings', TermInk.dim),
        ]);
    }
  }
}

class LaunchCommand extends TermCommand {
  const LaunchCommand({this.commandName = 'launch'});

  final String commandName;

  @override
  String get name => commandName;
  @override
  TermGroup get group => TermGroup.apps;
  @override
  String get help => 'open an app by name';
  @override
  String? get usage => '$commandName <app>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    // `am start firefox` is the same verb with the shape Android users know.
    final List<String> words = inv.positionals
        .where((String w) => w != 'start')
        .toList();
    if (words.isEmpty) return missing('an app name');

    final TermApp? app = await inv.context.vfs.appNamed(words.join(' '));
    if (app == null) {
      return TermResult.error('$commandName: no app matches ${words.join(' ')}');
    }
    await inv.context.host.launchApp(app);
    return TermResult.lines(<TermLine>[
      TermLine(<TermSpan>[
        const TermSpan('launching ', TermInk.dim),
        TermSpan(app.label),
        TermSpan('  ${app.packageName}', TermInk.dim),
      ]),
    ]);
  }
}

class WhichCommand extends TermCommand {
  const WhichCommand();

  @override
  String get name => 'which';
  @override
  TermGroup get group => TermGroup.apps;
  @override
  String get help => 'what a word resolves to';
  @override
  String? get usage => 'which <word>';

  @override
  Future<TermResult> run(TermInvocation inv) async {
    final String? word = inv.target;
    if (word == null) return missing('a word');

    final String? alias = inv.context.aliases[word];
    if (alias != null) {
      return TermResult.lines(<TermLine>[
        TermLine(<TermSpan>[
          TermSpan(word),
          const TermSpan(' is an alias for ', TermInk.dim),
          TermSpan(alias),
        ]),
      ]);
    }

    final TermCommand? command = TermRegistry.instance.lookup(word);
    if (command != null) {
      return TermResult.lines(<TermLine>[
        TermLine(<TermSpan>[
          TermSpan(word),
          const TermSpan(' is a shell builtin', TermInk.dim),
        ]),
        TermLine.of(command.help, TermInk.dim),
      ]);
    }

    final TermApp? app = await inv.context.vfs.appNamed(word);
    if (app != null) {
      return TermResult.lines(<TermLine>[
        TermLine(<TermSpan>[
          TermSpan(word),
          const TermSpan(' is an app, ', TermInk.dim),
          TermSpan(app.packageName, TermInk.dim),
        ]),
        TermLine.of('/apps/${app.slug}', TermInk.dim),
      ]);
    }
    return TermResult.line('$word matches nothing', TermInk.dim);
  }
}
