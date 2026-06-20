/*
 * Copyright (c) 2026 Neeraj Jakhar
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    log('Failed inspecting system distribution configuration settings: $e');
  }

  return LinuxFamily.unknown;
}
