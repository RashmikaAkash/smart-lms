import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key, this.userData = const {}});

  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    final name = userData['name']?.toString() ?? 'Student';
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
              'Student Dashboard',
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
