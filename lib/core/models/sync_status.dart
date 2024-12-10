import 'package:hive/hive.dart';

part 'sync_status.g.dart';

@HiveType(typeId: 0)
enum SyncStatus {
  @HiveField(0)
  synced,

  @HiveField(1)
  pending,

  @HiveField(2)
  error
}
