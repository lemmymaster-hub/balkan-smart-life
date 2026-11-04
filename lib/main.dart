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

  final cityContext = CityContext();
  try {
    await cityContext.load();
  } catch (error) {
    debugPrint('BSL city restore error: $error');
  }

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

Future<Stream<User?>> _initializeAuth() async {
  await Firebase.initializeApp();
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  } catch (error) {
    debugPrint('Firebase App Check init error: $error');
  }
  return FirebaseAuth.instance.authStateChanges();
}

class BslApp extends StatefulWidget {
  const BslApp({super.key});

  @override
  State<BslApp> createState() => _BslAppState();
}

class _BslAppState extends State<BslApp> {
  late Future<Stream<User?>> _auth = _initializeAuth();

  Widget _authError() => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => setState(() => _auth = _initializeAuth()),
        child: const Text('BSL prijava je nedostupna. Pokušaj ponovo.'),
      ),
    ),
  );

  static const _loading = Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Balkan Smart Life',
      theme: ThemeData.dark(),
      home: FutureBuilder<Stream<User?>>(
        future: _auth,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return _loading;
          if (snapshot.hasError) return _authError();
          return StreamBuilder<User?>(
            stream: snapshot.requireData,
            builder: (context, session) {
              if (session.hasError) return _authError();
              if (session.connectionState == ConnectionState.waiting) {
                return _loading;
              }
              final user = session.data;
              return user == null
                  ? const LoginScreen()
                  : HomeScreen(key: ValueKey(user.uid));
            },
          );
        },
      ),
    );
  }
}
