import 'package:flutter/material.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Scanner')),
      drawer: const AppDrawer(currentRoute: '/scanner'),
      body: const Center(
        child: Text('Scanner Screen - Coming Soon'),
      ),
    );
  }
}
