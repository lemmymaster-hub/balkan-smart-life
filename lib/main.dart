import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/context/bsl_location_context.dart';
import 'core/context/city_context.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized OK');

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      debugPrint('Firebase App Check initialized OK');
    } catch (error) {
      debugPrint('Firebase App Check init error: $error');
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  final cityContext = CityContext();
  await cityContext.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CityContext>.value(value: cityContext),
        ChangeNotifierProvider<BslLocationContext>(
          create: (_) => BslLocationContext(),
        ),
      ],
      child: const BslApp(),
    ),
  );
}

class BslApp extends StatelessWidget {
  const BslApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Balkan Smart Life',
      theme: ThemeData.dark(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const HomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
