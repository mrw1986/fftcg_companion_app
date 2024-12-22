import 'package:flutter_riverpod/flutter_riverpod.dart';

class RootRouteHistoryNotifier extends StateNotifier<List<int>> {
  RootRouteHistoryNotifier() : super([0]);

  void addHistory(int index) {
    // Only add to history if it's different from current
    if (state.isEmpty || state.last != index) {
      state = [...state, index];
    }
  }

  void removeLastHistory() {
    if (state.length > 1) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void clearHistory() {
    state = [0];
  }

  int get currentIndex => state.last;
  bool get canGoBack => state.length > 1;
}

final rootRouteHistoryProvider =
    StateNotifierProvider<RootRouteHistoryNotifier, List<int>>(
        (ref) => RootRouteHistoryNotifier());
