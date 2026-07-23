/*
 * Copyright (c) 2026 Neeraj Jakhar
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mixin/main_config_manager.dart';
import 'widgets/app_setup.dart';

abstract class MainWithAppSetupState<T extends StatefulWidget> extends State<T>
    implements MainConfigManager {
  @override
  List<AppSetupField> get appSetupFields;

  @override
  List<String> get storageKeys =>
      appSetupFields.map((f) => f.storageKey).toList();

  bool _initialized = false;
  bool _requireSetup = false;
  @override
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> initializeState(SharedPreferences sharedPreferences);

  Future<void> _initialize() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await initializeState(sharedPreferences);

    final allKeysExist = await hasConfigValues();

    setState(() {
      _initialized = true;
      _requireSetup = !allKeysExist;
    });
  }

  Widget buildMainApp(BuildContext context);

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return CircularProgressIndicator();
    }

    if (_requireSetup) {
      return AppSetup(this, appSetupFields, () async {
        final allKeysExist = await hasConfigValues();
        setState(() => _requireSetup = !allKeysExist);
      });
    }

    return buildMainApp(context);
  }
}
