import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/startup/app_update_cubit.dart';

class AutoUpdateDialog extends StatefulWidget {
  final String? downloadUrl;
  final String? latestVersion;
  final String? changeLog;
  final String upgradeFileName;
  const AutoUpdateDialog({
    required this.upgradeFileName,
    this.downloadUrl,
    this.latestVersion,
    this.changeLog,
    super.key,
  });

  @override
  State<AutoUpdateDialog> createState() => _AutoUpdateDialogState();
}

class _AutoUpdateDialogState extends State<AutoUpdateDialog> {
  late final AppUpdateCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = AppUpdateCubit(widget.upgradeFileName);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<AppUpdateCubit, AppUpdateStatus>(
        builder: (context, s) {
          final isProgress = s.state == AppUpdateState.inProgress;
          return PopScope(
            canPop: !isProgress,
            child: AlertDialog(
              title: Text(
                isProgress
                    ? 'Updating...'
                    : 'Update available: ${widget.latestVersion}',
              ),
              content: switch (s.state) {
                AppUpdateState.userInput => Text(
                  widget.changeLog ?? 'New version available',
                ),
                AppUpdateState.inProgress => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: s.event?.value != null
                          ? double.tryParse(s.event!.value!)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(s.event?.status.toString() ?? 'Downloading...'),
                  ],
                ),
                _ => Text(s.error ?? 'Something went wrong'),
              },
              actions: switch (s.state) {
                AppUpdateState.userInput => [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => _cubit.tryOtaUpdate(widget.downloadUrl!),
                    child: const Text('Update'),
                  ),
                ],
                AppUpdateState.inProgress => [],
                _ => [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              },
            ),
          );
        },
      ),
    );
  }
}
