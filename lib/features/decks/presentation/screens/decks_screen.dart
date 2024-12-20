import 'package:flutter/material.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../../core/presentation/widgets/app_bar_widget.dart';

class DecksScreen extends StatelessWidget {
  final VoidCallback? handleLogout;

  const DecksScreen({
    super.key,
    this.handleLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Decks',
        handleLogout: handleLogout,
      ),
      drawer: AppDrawer(
        currentRoute: '/decks',
        handleLogout: handleLogout,
      ),
      body: const Center(
        child: Text('Decks Screen - Coming Soon'),
      ),
    );
  }
}
