import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../../../../core/logging/talker_service.dart';

class LogsViewerScreen extends ConsumerStatefulWidget {
  const LogsViewerScreen({super.key});

  @override
  ConsumerState<LogsViewerScreen> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends ConsumerState<LogsViewerScreen> {
  late final TalkerService _talkerService;

  @override
  void initState() {
    super.initState();
    _talkerService = ref.read(talkerServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    return TalkerScreen(
      talker: _talkerService.talker,
      appBarTitle: 'App Logs',
      theme: TalkerScreenTheme(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        textColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
        cardColor: Theme.of(context).cardColor,
        logColors: {
          TalkerLogType.error.key: Theme.of(context).colorScheme.error,
          TalkerLogType.warning.key: Colors.orange,
          TalkerLogType.info.key: Theme.of(context).colorScheme.primary,
          TalkerLogType.debug.key: Colors.grey,
          TalkerLogType.verbose.key: Colors.grey[600] ?? Colors.grey,
          TalkerLogType.critical.key: Colors.redAccent,
        },
      ),
    );
  }
}
