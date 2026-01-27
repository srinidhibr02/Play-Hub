import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:play_hub/firebase_options.dart';
import 'package:play_hub/flavor_config.dart';

import 'package:play_hub/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  FlavorConfig.init(flavor);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SportsEventApp());
}

class SportsEventApp extends StatelessWidget {
  const SportsEventApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Play Hub',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
          accentColor: Colors.tealAccent,
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 2,
          ),
          titleLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w300,
            color: Colors.black54,
            letterSpacing: 1.5,
          ),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          prefixIconColor: Colors.teal.shade700,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            shadowColor: Colors.tealAccent.withAlpha((255 * 0.5).toInt()),
            elevation: 5,
          ),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.teal.shade700,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.tealAccent.shade400],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
