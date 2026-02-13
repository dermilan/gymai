import 'package:flutter/foundation.dart';

import 'models/user_prefs.dart';
import 'services/openrouter_client.dart';
import 'storage/local_store.dart';
import 'storage/shared_prefs_store.dart';

class AppServices {
  static final LocalStore store = SharedPrefsStore();
  static final ValueNotifier<int> workoutsRefresh = ValueNotifier(0);
  static final ValueNotifier<int> prefsRefresh = ValueNotifier(0);

  static OpenRouterClient createAiClient(UserPrefs prefs) {
    return OpenRouterClient(
      apiKey: prefs.apiKey,
      model: prefs.model,
      title: 'Gym Progress AI',
    );
  }
}
