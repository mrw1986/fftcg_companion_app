import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/talker_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  InternetConnectionChecker _connectionChecker = InternetConnectionChecker();
  final TalkerService _talker = TalkerService();

  final _connectivityController = StreamController<bool>.broadcast();
  bool _lastKnownStatus = false;

  ConnectivityService() {
    _initializeConnectivityStream();
  }

  void _initializeConnectivityStream() {
    _connectivity.onConnectivityChanged.listen((result) async {
      await _checkAndUpdateConnectivity(result);
    });

    _connectivity.checkConnectivity().then((result) async {
      await _checkAndUpdateConnectivity(result);
    });
  }

  Future<void> _checkAndUpdateConnectivity(
      List<ConnectivityResult> results) async {
    try {
      bool hasConnection = false;

      if (!results.contains(ConnectivityResult.none)) {
        hasConnection = await _connectionChecker.hasConnection;
      }

      if (hasConnection != _lastKnownStatus) {
        _lastKnownStatus = hasConnection;
        _connectivityController.add(hasConnection);
        _talker.info(
            'Connectivity status changed: ${hasConnection ? 'online' : 'offline'}');
      }
    } catch (e, stackTrace) {
      _talker.severe('Error checking connectivity', e, stackTrace);
      if (_lastKnownStatus) {
        _lastKnownStatus = false;
        _connectivityController.add(false);
      }
    }
  }

  /// Stream of connectivity status changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current connectivity status
  Future<bool> get isConnected async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.none)) {
        return false;
      }
      return await _connectionChecker.hasConnection;
    } catch (e, stackTrace) {
      _talker.severe('Error checking current connectivity', e, stackTrace);
      return false;
    }
  }

  /// Check if we have a stable connection
  Future<bool> hasStableConnection() async {
    try {
      // Check internet connection
      final hasConnection = await _connectionChecker.hasConnection;
      if (!hasConnection) return false;

      // Check specific host reachability
      final hostReachable = await _connectionChecker.isHostReachable(
        AddressCheckOptions(
          hostname: 'google.com',
          port: 443,
          timeout: const Duration(seconds: 3),
        ),
      );

      return hostReachable.isSuccess;
    } catch (e, stackTrace) {
      _talker.severe('Error checking stable connection', e, stackTrace);
      return false;
    }
  }

  /// Configuration for connection checker
  Future<void> configureConnectionChecker({
    Duration? checkInterval,
    Duration? timeout,
    List<AddressCheckOptions>? addresses,
  }) async {
    try {
      if (checkInterval != null || timeout != null || addresses != null) {
        // Create a new instance with updated configuration
        _connectionChecker = InternetConnectionChecker.createInstance(
          checkInterval: checkInterval ?? _connectionChecker.checkInterval,
          checkTimeout: timeout ?? _connectionChecker.checkTimeout,
          addresses: addresses ?? _connectionChecker.addresses,
        );
        _talker.info('Connection checker configured successfully');
      }
    } catch (e, stackTrace) {
      _talker.severe('Error configuring connection checker', e, stackTrace);
    }
  }

  /// Get detailed connection status
  Future<ConnectionStatus> getDetailedConnectionStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = await _connectionChecker.hasConnection;

      return ConnectionStatus(
        isConnected: hasConnection,
        connectionTypes: results,
        lastChecked: DateTime.now(),
      );
    } catch (e, stackTrace) {
      _talker.severe('Error getting detailed connection status', e, stackTrace);
      return ConnectionStatus(
        isConnected: false,
        connectionTypes: [],
        lastChecked: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  void dispose() {
    _connectivityController.close();
  }
}

class ConnectionStatus {
  final bool isConnected;
  final List<ConnectivityResult> connectionTypes;
  final DateTime lastChecked;
  final String? error;

  ConnectionStatus({
    required this.isConnected,
    required this.connectionTypes,
    required this.lastChecked,
    this.error,
  });

  bool get hasWifi => connectionTypes.contains(ConnectivityResult.wifi);
  bool get hasMobile => connectionTypes.contains(ConnectivityResult.mobile);
  bool get hasEthernet => connectionTypes.contains(ConnectivityResult.ethernet);
  bool get hasVPN => connectionTypes.contains(ConnectivityResult.vpn);
  bool get hasError => error != null;

  @override
  String toString() {
    return 'ConnectionStatus(isConnected: $isConnected, types: $connectionTypes, lastChecked: $lastChecked, error: $error)';
  }
}

// Provider for detailed connection status
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) async* {
  final connectivityService = ref.watch(connectivityServiceProvider);

  // Initial status
  yield await connectivityService.getDetailedConnectionStatus();

  // Stream of updates
  await for (final _ in connectivityService.connectivityStream) {
    yield await connectivityService.getDetailedConnectionStatus();
  }
});

// Provider for simple connection status
final isConnectedProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.connectivityStream;
});
