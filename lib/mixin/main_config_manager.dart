/*
 * Copyright (c) 2026 Neeraj Jakhar
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../widgets/app_setup.dart';

mixin MainConfigManager {
  List<String> get storageKeys;
  List<AppSetupField> get appSetupFields;
  FlutterSecureStorage get secureStorage;

  void notifyConfigReload();

  Future<Map<String, dynamic>> getConfigValues() async {
    final configBackup = Map<String, dynamic>.fromEntries(
      await Future.wait(
        storageKeys.map(
          (key) async => MapEntry(key, await secureStorage.read(key: key)),
        ),
      ),
    );

    configBackup["timestamp"] = DateTime.now().toIso8601String();

    return configBackup;
  }

  Future<bool> hasConfigValues() async {
    final config = await getConfigValues();
    return appSetupFields.every(
      (f) => f.emptyAllowed ?? false || config[f.storageKey] != null,
    );
  }

  Future<void> setConfigValues(Map<String, dynamic> config) async {
    for (final key in storageKeys) {
      if (config.containsKey(key)) {
        await secureStorage.write(key: key, value: config[key]);
      }
    }

    notifyConfigReload();
  }

  Future<String?> exportSystemPreferences() async {
    try {
      final configBackup = await getConfigValues();
      final String jsonString = json.encode(configBackup);
      final Uint8List fileBytes = Uint8List.fromList(utf8.encode(jsonString));

      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Export Configuration Settings',
        fileName: 'tennis_tool_config_backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: fileBytes,
      );

      if (outputPath != null) {
        await File(outputPath).writeAsBytes(fileBytes);
        return "Configuration keys backed up cleanly!";
      }
    } catch (e) {
      return "Export failed: $e";
    }
    return null;
  }

  Future<String?> importSystemPreferences() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final File selectedFile = File(result.files.single.path!);
        final Map<String, dynamic> config = json.decode(
          await selectedFile.readAsString(),
        );

        await setConfigValues(config);
        if (await hasConfigValues()) {
          return null;
        } else {
          return 'Import failed: Some configuration parameters are missing';
        }
      } else {
        return 'Import failed: No file selected';
      }
    } catch (e) {
      return "Import failed: Invalid configuration template. $e";
    }
  }

  Future<String?> importSystemPreferencesFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim();

      if (text == null || text.isEmpty) {
        return 'Import failed: Clipboard is empty';
      }

      final Map<String, dynamic> config = json.decode(text);
      await setConfigValues(config);

      return await hasConfigValues()
          ? null
          : 'Import failed: Some configuration parameters are missing';
    } catch (e) {
      return "Import failed: Invalid JSON in clipboard. $e";
    }
  }
}
