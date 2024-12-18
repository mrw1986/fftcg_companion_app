import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_stats.dart';

final userStatsProvider = StateProvider<UserStats>((ref) {
  return const UserStats();
});
