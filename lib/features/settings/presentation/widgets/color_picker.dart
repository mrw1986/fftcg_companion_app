import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';

class ColorPicker extends ConsumerWidget {
  const ColorPicker({super.key});

  static const List<Color> _colors = [
    Colors.purple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(themeColorProvider);

    return ListTile(
      title: const Text('Theme Color'),
      subtitle: const Text('Choose your accent color'),
      trailing: Wrap(
        children: _colors.map((color) {
          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: GestureDetector(
              onTap: () {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setThemeColor(color);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selectedColor == color
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
