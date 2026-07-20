/// `core` — LIFTABLE.
///
/// This folder becomes `packages/g_core/` the day G Recovery starts, and the
/// whole point of the barrel is to make that a file move rather than a
/// refactor.
///
/// ONE RULE: nothing in here may import anything launcher-specific. No
/// `engine/`, no `shells/`, no `features/`, and no Flutter widgets unless
/// there is genuinely no way around it.
///
/// The rule sounds pedantic until it is broken. A single `import
/// '../engine/theme_spec.dart'` inside a logger drags the entire theme engine
/// into a package that G Recovery is supposed to be able to depend on, and the
/// lift stops being an afternoon.
///
/// (This doc replaces `core/README.md`. Rationale lives next to the code it
/// governs, because a README beside source is a second place for truth to live
/// and therefore a second place for it to rot — which is exactly what happened
/// to six of the thirteen READMEs this file is part of retiring.)
library;

export 'analytics.dart';
export 'env.dart';
export 'logger.dart';
export 'result.dart';
