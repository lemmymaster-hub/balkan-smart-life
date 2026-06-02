import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    print('Firebase initialized OK');
  } catch (e) {
    print('Firebase init error: $e');
  }
  runApp(const BslApp());
}

class BslApp extends StatelessWidget {
  const BslApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Balkan Smart Life',
      theme: ThemeData.dark(),
      home: StreamBuilder(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
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
