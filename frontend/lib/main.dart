import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final appConfig = AppConfig.fromEnvironment();

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(appConfig)],
      child: const TestLabUzApp(),
    ),
  );
}
