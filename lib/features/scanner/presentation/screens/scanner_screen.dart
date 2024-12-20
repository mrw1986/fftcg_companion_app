import 'package:flutter/material.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../../core/presentation/widgets/app_bar_widget.dart';

class ScannerScreen extends StatelessWidget {
  final VoidCallback? handleLogout;

  const ScannerScreen({
    super.key,
    this.handleLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Card Scanner',
        handleLogout: handleLogout,
      ),
      drawer: AppDrawer(
        currentRoute: '/scanner',
        handleLogout: handleLogout,
      ),
      body: const Center(
        child: Text('Scanner Screen - Coming Soon'),
      ),
    );
  }
}
