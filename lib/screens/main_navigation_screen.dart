import 'package:flutter/material.dart';
import '../widgets/responsive_body.dart';
import 'auth/login_screen.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({
    super.key,
    required this.namaPahlawan,
    required this.email,
  });

  final String namaPahlawan;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda FinQuest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ResponsiveBody(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 40)),
                const SizedBox(height: 16),
                Text('Halo, $namaPahlawan!', style: Theme.of(context).textTheme.titleLarge),
                Text(email),
                const SizedBox(height: 24),
                const Text('Halo cuy!'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}