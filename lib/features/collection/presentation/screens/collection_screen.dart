import 'package:flutter/material.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../../core/presentation/widgets/app_bar_widget.dart';

class CollectionScreen extends StatelessWidget {
  final VoidCallback? handleLogout;

  const CollectionScreen({
    super.key,
    this.handleLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'My Collection',
        handleLogout: handleLogout,
      ),
      drawer: AppDrawer(
        currentRoute: '/collection',
        handleLogout: handleLogout,
      ),
      body: const Center(
        child: Text('Collection Screen - Coming Soon'),
      ),
    );
  }
}
