import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MyApp(
      firebaseInitialization: Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.firebaseInitialization});

  final Future<FirebaseApp>? firebaseInitialization;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart LMS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: firebaseInitialization == null
          ? const LoginPage()
          : FutureBuilder<FirebaseApp>(
              future: firebaseInitialization,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const StartupLoadingPage();
                }

                if (snapshot.hasError) {
                  return StartupErrorPage(error: snapshot.error.toString());
                }

                return const AuthGate();
              },
            ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const StartupLoadingPage();
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return AuthenticatedDashboard(user: user);
      },
    );
  }
}

class AuthenticatedDashboard extends StatelessWidget {
  const AuthenticatedDashboard({super.key, required this.user});

  final User user;

  Map<String, dynamic> get _fallbackData {
    final email = user.email ?? '';
    final fallbackName = email.contains('@') ? email.split('@').first : email;

    return <String, dynamic>{
      'id': user.uid,
      'name': user.displayName?.isNotEmpty == true
          ? user.displayName
          : fallbackName,
      'email': email,
      'role': 'student',
    };
  }

  Future<Map<String, dynamic>> _loadUserData() async {
    final fallbackData = _fallbackData;

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final firestoreData = userSnapshot.data();

      if (firestoreData == null) {
        return fallbackData;
      }

      return <String, dynamic>{
        ...fallbackData,
        ...firestoreData,
        'id': user.uid,
        'email': firestoreData['email']?.toString().isNotEmpty == true
            ? firestoreData['email']
            : user.email ?? '',
      };
    } on FirebaseException {
      return fallbackData;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const StartupLoadingPage();
        }

        final userData = snapshot.data ?? _fallbackData;
        final role = (userData['role']?.toString() ?? '').trim().toLowerCase();

        if (role == 'teacher') {
          return TeacherDashboard(userData: userData);
        }

        return StudentDashboard(userData: userData);
      },
    );
  }
}

class StartupLoadingPage extends StatelessWidget {
  const StartupLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D47A1),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Firebase setup failed',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: const TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
