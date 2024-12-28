// lib/core/services/background_sync_service.dart

import 'package:workmanager/workmanager.dart';
import '../logging/talker_service.dart';
import 'sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const backgroundSyncTask = 'backgroundSync';
const periodicSyncTask = 'periodicSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final talker = TalkerService();
    try {
      switch (task) {
        case backgroundSyncTask:
          final container = ProviderContainer();
          final syncService = container.read(syncServiceProvider);
          await syncService.syncPendingChanges();
          break;
        case periodicSyncTask:
          final container = ProviderContainer();
          final syncService = container.read(syncServiceProvider);
          await syncService.syncPendingChanges();
          break;
      }
      return true;
    } catch (e, stackTrace) {
      talker.severe('Background sync failed', e, stackTrace);
      return false;
    }
  });
}

class BackgroundSyncService {
  final TalkerService _talker;
  static const Duration _minimumSyncInterval = Duration(minutes: 15);
  static const Duration _periodicSyncInterval = Duration(hours: 1);

  BackgroundSyncService({TalkerService? talker})
      : _talker = talker ?? TalkerService();

  Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
      _talker.info('Background sync service initialized');
    } catch (e, stackTrace) {
      _talker.severe('Failed to initialize background sync', e, stackTrace);
      rethrow;
    }
  }

  Future<void> scheduleSync({bool force = false}) async {
    try {
      await Workmanager().registerOneOffTask(
        backgroundSyncTask,
        backgroundSyncTask,
        initialDelay: force ? Duration.zero : _minimumSyncInterval,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      _talker.info('Background sync scheduled');
    } catch (e, stackTrace) {
      _talker.severe('Failed to schedule background sync', e, stackTrace);
      rethrow;
    }
  }

  Future<void> enablePeriodicSync() async {
    try {
      await Workmanager().registerPeriodicTask(
        periodicSyncTask,
        periodicSyncTask,
        frequency: _periodicSyncInterval,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
      _talker.info('Periodic sync enabled');
    } catch (e, stackTrace) {
      _talker.severe('Failed to enable periodic sync', e, stackTrace);
      rethrow;
    }
  }

  Future<void> disablePeriodicSync() async {
    try {
      await Workmanager().cancelByUniqueName(periodicSyncTask);
      _talker.info('Periodic sync disabled');
    } catch (e, stackTrace) {
      _talker.severe('Failed to disable periodic sync', e, stackTrace);
      rethrow;
    }
  }

  Future<void> cancelAllSync() async {
    try {
      await Workmanager().cancelAll();
      _talker.info('All sync tasks cancelled');
    } catch (e, stackTrace) {
      _talker.severe('Failed to cancel sync tasks', e, stackTrace);
      rethrow;
    }
  }
}

// Provider
final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  return BackgroundSyncService();
});
