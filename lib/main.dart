import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
    if (firebaseInitialization == null) {
      return const SmartLmsApp(
        settings: AppSettingsData.defaults(),
        home: LoginPage(),
      );
    }

    return FutureBuilder<FirebaseApp>(
      future: firebaseInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SmartLmsApp(
            settings: AppSettingsData.defaults(),
            home: StartupLoadingPage(),
          );
        }

        if (snapshot.hasError) {
          return SmartLmsApp(
            settings: const AppSettingsData.defaults(),
            home: StartupErrorPage(error: snapshot.error.toString()),
          );
        }

        return const SettingsAwareApp();
      },
    );
  }
}

class SettingsAwareApp extends StatelessWidget {
  const SettingsAwareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const SmartLmsApp(
            settings: AppSettingsData.defaults(),
            home: StartupLoadingPage(),
          );
        }

        if (user == null) {
          return const SmartLmsApp(
            settings: AppSettingsData.defaults(),
            home: LoginPage(),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            final settings = AppSettingsData.fromUserData(
              userSnapshot.data?.data(),
            );

            return SmartLmsApp(
              settings: settings,
              home: AuthenticatedDashboard(user: user),
            );
          },
        );
      },
    );
  }
}

class SmartLmsApp extends StatelessWidget {
  const SmartLmsApp({
    super.key,
    required this.settings,
    required this.home,
  });

  final AppSettingsData settings;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart LMS',
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
      ),
      locale: const Locale('en'),
      supportedLocales: const [
        Locale('en'),
        Locale('si'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}

class AppSettingsData {
  const AppSettingsData({
    required this.darkMode,
  });

  const AppSettingsData.defaults() : darkMode = false;

  final bool darkMode;

  factory AppSettingsData.fromUserData(Map<String, dynamic>? data) {
    final settings = data?['settings'];
    if (settings is! Map) {
      return const AppSettingsData.defaults();
    }

    return AppSettingsData(
      darkMode: settings['darkMode'] == true,
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _userDataStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();
  }

  Map<String, dynamic> _mergeUserData(Map<String, dynamic>? firestoreData) {
    final fallbackData = _fallbackData;

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
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDataStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const StartupLoadingPage();
        }

        final userData = snapshot.hasError
            ? _fallbackData
            : _mergeUserData(snapshot.data?.data());
        final role = (userData['role']?.toString() ?? '').trim().toLowerCase();
        final status =
            (userData['status']?.toString() ?? '').trim().toLowerCase();

        if (status == 'archived') {
          return const RemovedAccountPage();
        }

        if (role == 'teacher') {
          return TeacherDashboard(userData: userData);
        }

        return StudentDashboard(userData: userData);
      },
    );
  }
}

class RemovedAccountPage extends StatelessWidget {
  const RemovedAccountPage({super.key});

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
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    color: Color(0xFFFF526B),
                    size: 46,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Account removed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF071B3C),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'මේ student account එක teacher විසින් remove කරලා තියෙනවා. නැවත access ඕන නම් teacher contact කරන්න.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF66748F),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign Out'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF316DFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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

class StartupLoadingPage extends StatefulWidget {
  const StartupLoadingPage({super.key});

  @override
  State<StartupLoadingPage> createState() => _StartupLoadingPageState();
}

class _StartupLoadingPageState extends State<StartupLoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 0.94)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_controller);
    _slide = Tween<double>(begin: -18, end: 18).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final animationValue = _controller.value;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF081B4D),
                  Color(0xFF1453D9),
                  Color(0xFF6D35F4),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -88 + _slide.value,
                  right: -58,
                  child: _SplashGlow(
                    size: 190,
                    color: Colors.white.withOpacity(0.13),
                  ),
                ),
                Positioned(
                  bottom: -72 - _slide.value,
                  left: -62,
                  child: _SplashGlow(
                    size: 210,
                    color: const Color(0xFF21E6C1).withOpacity(0.18),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: _pulse.value,
                            child: SizedBox(
                              width: 154,
                              height: 154,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Transform.rotate(
                                    angle: animationValue * math.pi * 2,
                                    child: CustomPaint(
                                      size: const Size.square(154),
                                      painter: _SplashOrbitPainter(
                                        progress: animationValue,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.16),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.55),
                                        width: 1.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF21E6C1)
                                              .withOpacity(0.34),
                                          blurRadius: 32,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.auto_stories_rounded,
                                      color: Colors.white,
                                      size: 52,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Smart LMS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              letterSpacing: 0.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading your learning space',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _SplashProgress(progress: animationValue),
                          const SizedBox(height: 18),
                          _LoadingDots(progress: animationValue),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SplashGlow extends StatelessWidget {
  const _SplashGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _SplashProgress extends StatelessWidget {
  const _SplashProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.22 + (math.sin(progress * math.pi * 2) + 1) * 0.34,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF21E6C1),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF21E6C1).withOpacity(0.55),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final dotProgress = (progress + index * 0.18) % 1;
        final opacity = 0.35 + (math.sin(dotProgress * math.pi * 2) + 1) * 0.32;
        final offset = -4 * math.sin(dotProgress * math.pi * 2);

        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity.clamp(0.35, 1)),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

class _SplashOrbitPainter extends CustomPainter {
  const _SplashOrbitPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final orbitRect = Rect.fromCircle(center: center, radius: size.width / 2.2);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withOpacity(0.18);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..shader = const SweepGradient(
        colors: [
          Color(0x0021E6C1),
          Color(0xFF21E6C1),
          Colors.white,
          Color(0x0021E6C1),
        ],
      ).createShader(orbitRect);

    canvas.drawCircle(center, size.width / 2.2, glowPaint);
    canvas.drawArc(
      orbitRect,
      -math.pi / 2 + progress * math.pi * 2,
      math.pi * 1.15,
      false,
      arcPaint,
    );

    final dotAngle = progress * math.pi * 2;
    final dotOffset = Offset(
      center.dx + math.cos(dotAngle) * size.width / 2.2,
      center.dy + math.sin(dotAngle) * size.width / 2.2,
    );
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(dotOffset, 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SplashOrbitPainter oldDelegate) {
    return oldDelegate.progress != progress;
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
