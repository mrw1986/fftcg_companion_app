import 'package:flutter/material.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Collection')),
      drawer: const AppDrawer(currentRoute: '/collection'),
      body: const Center(
        child: Text('Collection Screen - Coming Soon'),
      ),
    );
  }
}
