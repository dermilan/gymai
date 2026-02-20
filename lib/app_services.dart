import 'package:flutter/foundation.dart';

import 'services/ai_proxy_client.dart';
import 'storage/local_store.dart';
import 'storage/database_store.dart';
import 'storage/shared_prefs_store.dart';

/// @deprecated Use Riverpod providers from providers.dart instead.
/// This class is kept for backward compatibility during migration.
class AppServices {
  /// @deprecated Use storeProvider from providers.dart
  static final LocalStore _store = kIsWeb ? SharedPrefsStore() : DatabaseStore();
  static LocalStore get store => _store;

  /// @deprecated Use aiProxyProvider from providers.dart
  static AiProxyClient? _aiProxy;
  static AiProxyClient get aiProxy => _aiProxy ??= AiProxyClient();
}
