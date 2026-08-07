/*
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'dart:io';

import 'package:dart_ipify/dart_ipify.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_common/app_logger.dart';

void showSnackBar(BuildContext context, String message, {Duration? timeout}) {
  final snackBar = SnackBar(
    content: Text(message),
    duration: timeout ?? const Duration(seconds: 3),
    persist: false,
    action: SnackBarAction(label: 'Ok', onPressed: () {}),
  );
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

void showErrorDialog(BuildContext context, String largeMessage) {
  final scrollController = ScrollController();

  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Error'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 400, maxWidth: 400),
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(right: 12),
            child: SelectableText(largeMessage),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text('Copy')),
        TextButton(onPressed: () => Navigator.pop(c), child: Text('OK')),
      ],
    ),
  );
}

Future<bool> showConfirmDialog(
  BuildContext context,
  String title,
  String message, {
  bool isDeletion = false,
  String okText = 'Yes',
  String cancleText = 'Dismiss',
  VoidCallback? okAction,
  VoidCallback? cancleAction,
}) async {
  return await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            if (cancleAction != null) cancleAction();
            Navigator.pop(ctx, false);
          },
          child: Text(cancleText),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDeletion
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (okAction != null) okAction();
            Navigator.pop(ctx, true);
          },
          child: Text(okText),
        ),
      ],
    ),
  );
}

bool isDesktopPlatform() =>
    !kIsWeb && (isLinuxPlatform() || isWindowsPlatform() || isMacOSPlatform());
bool isWindowsPlatform() => Platform.isWindows;
bool isLinuxPlatform() => Platform.isLinux;
bool isMacOSPlatform() => Platform.isMacOS;
bool isMobilePlatform() => !kIsWeb && (isAndroidPlatform() || isIOSPlatform());
bool isAndroidPlatform() => !kIsWeb && Platform.isAndroid;
bool isIOSPlatform() => !kIsWeb && Platform.isIOS;
bool isWebPlatform() => kIsWeb;

enum LinuxFamily { arch, debian, unknown }

LinuxFamily getLinuxDistributionFamily() {
  try {
    final File osReleaseFile = File('/etc/os-release');
    if (!osReleaseFile.existsSync()) return LinuxFamily.unknown;

    final List<String> lines = osReleaseFile.readAsLinesSync();

    String id = '';
    List<String> idLike = [];

    for (var line in lines) {
      final cleanedLine = line
          .trim()
          .replaceAll('"', '')
          .replaceAll("'", '')
          .toLowerCase();

      if (cleanedLine.startsWith('id=')) {
        id = cleanedLine.substring(3).trim();
      } else if (cleanedLine.startsWith('id_like=')) {
        idLike = cleanedLine.substring(8).trim().split(' ');
      }
    }

    if (id == 'debian' ||
        id == 'ubuntu' ||
        idLike.contains('debian') ||
        idLike.contains('ubuntu')) {
      return LinuxFamily.debian;
    }

    if (id == 'arch' || id == 'manjaro' || idLike.contains('arch')) {
      return LinuxFamily.arch;
    }
  } catch (e) {
    appLogger.e(
      'Failed inspecting system distribution configuration settings: $e',
    );
  }

  return LinuxFamily.unknown;
}

String? cachedIpAddress;

Future<Map<String, dynamic>> generateAuditPayload() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String platformLabel = "Unknown";
  String identifier = "Unknown";

  try {
    if (isAndroidPlatform()) {
      final info = await deviceInfo.androidInfo;
      platformLabel = "Android (${info.brand} ${info.model})";
      identifier = info.id;
    } else if (isIOSPlatform()) {
      final info = await deviceInfo.iosInfo;
      platformLabel = "iOS (${info.model})";
      identifier = info.identifierForVendor ?? "Unknown_iOS";
    } else if (isWindowsPlatform()) {
      final info = await deviceInfo.windowsInfo;
      platformLabel = "Windows";
      identifier = info.computerName;
    } else if (isLinuxPlatform()) {
      final info = await deviceInfo.linuxInfo;
      platformLabel = "Linux (${info.name})";
      identifier = info.machineId ?? "Unknown_Linux";
    }
  } catch (e) {
    appLogger.e('Error getting device info: $e');
  }

  if (cachedIpAddress == null) {
    try {
      cachedIpAddress = await Ipify.ipv4().timeout(Duration(seconds: 3));
    } catch (e) {
      appLogger.e('Error getting IP info: $e');
    }
  }

  return {
    "device_platform": platformLabel,
    "device_hardware_id": identifier,
    "client_ip_address": cachedIpAddress ?? '0.0.0.0',
    "sync_timestamp": DateTime.now().toIso8601String(),
  };
}
