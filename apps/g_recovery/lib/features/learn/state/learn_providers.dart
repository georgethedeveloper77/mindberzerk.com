import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/content_store.dart';
import 'learn_model.dart';

final FutureProvider<LearnBook> learnBookProvider =
    FutureProvider<LearnBook>((Ref ref) async {
  final Map<String, Object?> json =
      await ref.watch(contentStoreProvider).readJson(ContentStore.learn);
  return LearnBook.fromJson(json);
});
