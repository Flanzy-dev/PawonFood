import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/data/onboarding_repository.dart';
import 'core/data/providers.dart';
import 'core/mock/mock_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  final data = await MockData.load(rootBundle);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [mockDataProvider.overrideWithValue(data), preferencesProvider.overrideWithValue(prefs)], child: const PawonApp()));
}
