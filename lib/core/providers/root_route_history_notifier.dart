import 'package:flutter_riverpod/flutter_riverpod.dart';

class RootRouteHistoryNotifier extends StateNotifier<List<int>> {
  RootRouteHistoryNotifier() : super([0]); // Initialize with home tab (index 0)

  List<int> get history => state;

  void addHistory(int index) {
    state = [...state, index];
  }

  void removeLastHistory() {
    if (state.length > 1) {
      final newState = [...state];
      newState.removeLast();
      state = newState;
    }
  }

  void clearHistory() {
    state = [0]; // Reset to home tab
  }
}

final rootRouteHistoryProvider =
    StateNotifierProvider<RootRouteHistoryNotifier, List<int>>(
        (ref) => RootRouteHistoryNotifier());
