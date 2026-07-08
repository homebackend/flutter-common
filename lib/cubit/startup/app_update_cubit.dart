/*
 * Copyright (c) 2026 Neeraj Jakhar
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_common/tool.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:path_provider/path_provider.dart';

part 'app_update_state.dart';

class AppUpdateCubit extends Cubit<AppUpdateStatus> {
  final String upgradeFileName;
  AppUpdateCubit(this.upgradeFileName)
    : super(AppUpdateStatus(AppUpdateState.userInput));

  Future<void> tryOtaUpdate(String downloadUrl) async {
    try {
      log('Download url: $downloadUrl');
      OtaUpdate()
          .execute(downloadUrl, destinationFilename: upgradeFileName)
          .listen((OtaEvent event) {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
              case OtaStatus.INSTALLING:
                emit(AppUpdateStatus(AppUpdateState.inProgress, event: event));
              case OtaStatus.INSTALLATION_DONE:
                log('Installation done. Ideally this should never come');
              case OtaStatus.ALREADY_RUNNING_ERROR:
              case OtaStatus.INSTALLATION_ERROR:
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              case OtaStatus.INTERNAL_ERROR:
              case OtaStatus.DOWNLOAD_ERROR:
              case OtaStatus.CHECKSUM_ERROR:
              case OtaStatus.CANCELED:
                emit(
                  AppUpdateStatus(
                    AppUpdateState.error,
                    error: event.status.toString(),
                  ),
                );
            }
          });
    } catch (e) {
      emit(AppUpdateStatus(AppUpdateState.error, error: e.toString()));
    }
  }

  void skipUpdate() => emit(AppUpdateStatus(AppUpdateState.skipped));

  Future<void> tryLinuxUpdate(String url) async {
    final tempDir = await getTemporaryDirectory();
    final tmpPath = '${tempDir.path}/$upgradeFileName';

    try {
      emit(
        AppUpdateStatus(
          AppUpdateState.inProgress,
          event: OtaEvent(OtaStatus.DOWNLOADING, 'Downloading...'),
        ),
      );

      if (!await _downloadPackage(url, tmpPath)) return;

      final family = getLinuxDistributionFamily();
      final escalator = await _findEscalator();
      if (escalator == null) {
        emit(
          AppUpdateStatus(
            AppUpdateState.error,
            error: 'No pkexec/sudo/doas found',
          ),
        );
        return;
      }

      List<String> cmd;
      switch (family) {
        case LinuxFamily.arch:
          cmd = [escalator, '/usr/bin/pacman', '-U', '--noconfirm', tmpPath];
          break;
        case LinuxFamily.debian:
          cmd = [escalator, '/usr/bin/dpkg', '-i', tmpPath];
          break;
        default:
          emit(
            AppUpdateStatus(
              AppUpdateState.error,
              error: 'Unsupported Linux distro',
            ),
          );
          return;
      }

      emit(
        AppUpdateStatus(
          AppUpdateState.inProgress,
          event: OtaEvent(
            OtaStatus.INSTALLING,
            'Installing (admin password required)...',
          ),
        ),
      );

      final proc = await Process.start(cmd.first, cmd.sublist(1));
      proc.stdout.transform(utf8.decoder).listen(log);
      proc.stderr.transform(utf8.decoder).listen(log);

      final exitCode = await proc.exitCode;

      if (await File(tmpPath).exists()) {
        await File(tmpPath).delete();
      }

      if (exitCode != 0) {
        emit(
          AppUpdateStatus(
            AppUpdateState.error,
            error: 'Installer exited with code $exitCode',
          ),
        );
        return;
      }

      emit(
        AppUpdateStatus(
          AppUpdateState.inProgress,
          event: OtaEvent(
            OtaStatus.INSTALLING,
            'Update installed. Restarting...',
          ),
        ),
      );

      emit(
        AppUpdateStatus(
          AppUpdateState.inProgress,
          event: OtaEvent(
            OtaStatus.INSTALLING,
            'Update installed. Restarting...',
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final exe = Platform.resolvedExecutable;

      try {
        await Process.start(exe, [], mode: ProcessStartMode.detached);
      } catch (e) {
        log('Auto-restart failed: $e — user will need to launch manually');
      }

      exit(0);
    } catch (e) {
      final f = File(tmpPath);
      if (await f.exists()) await f.delete().catchError((_) {});
      emit(AppUpdateStatus(AppUpdateState.error, error: e.toString()));
    }
  }

  Future<bool> _downloadPackage(String url, String tmpPath) async {
    emit(
      AppUpdateStatus(
        AppUpdateState.inProgress,
        event: OtaEvent(OtaStatus.DOWNLOADING, '0%'),
      ),
    );

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      emit(
        AppUpdateStatus(
          AppUpdateState.error,
          error: 'Download failed ${response.statusCode}',
        ),
      );
      return false;
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    var lastPercent = -1;
    final file = await File(tmpPath).create();
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      received += chunk.length;
      sink.add(chunk);

      if (total > 0) {
        final percent = ((received / total) * 100).floor();

        if (percent != lastPercent) {
          lastPercent = percent;
          emit(
            AppUpdateStatus(
              AppUpdateState.inProgress,
              event: OtaEvent(OtaStatus.DOWNLOADING, '$percent%'),
            ),
          );
        }
        await Future.delayed(Duration.zero);
      } else {
        final mb = (received / 1024 / 1024).toStringAsFixed(1);
        emit(
          AppUpdateStatus(
            AppUpdateState.inProgress,
            event: OtaEvent(OtaStatus.DOWNLOADING, '$mb MB'),
          ),
        );
      }
    }

    await sink.close();

    emit(
      AppUpdateStatus(
        AppUpdateState.inProgress,
        event: OtaEvent(OtaStatus.DOWNLOADING, '100%'),
      ),
    );

    return true;
  }

  Future<String?> _findEscalator() async {
    for (final c in ['pkexec', 'sudo', 'doas']) {
      if ((await Process.run('which', [c])).exitCode == 0) return c;
    }
    return null;
  }
}
