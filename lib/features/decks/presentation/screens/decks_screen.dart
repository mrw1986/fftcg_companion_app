import 'package:flutter/material.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class DecksScreen extends StatelessWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decks')),
      drawer: const AppDrawer(currentRoute: '/decks'),
      body: const Center(
        child: Text('Decks Screen - Coming Soon'),
      ),
    );
  }
}
