import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key, this.userData = const {}});

  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    final name = userData['name']?.toString() ?? 'Teacher';
    final email = userData['email']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello $name'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Teacher Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(email),
            ],
          ],
        ),
      ),
    );
  }
}
