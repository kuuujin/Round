import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  // 1. Accept the user ID passed during navigation
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Example logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // TODO: Implement logout logic (clear session/user data)
              Navigator.pushReplacementNamed(context, '/login'); // Go back to login
            },
          )
        ],
      ),
      body: Center(
        // 2. Display the logged-in user ID
        child: Text(
          'Welcome, $userId!', // Display the ID
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}