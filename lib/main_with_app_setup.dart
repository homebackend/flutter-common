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
  List<AppSetupField> get appSetupFields;

  @override
  List<String> get storageKeys =>
      appSetupFields.map((f) => f.storageKey).toList();

  bool _initialized = false;
  bool _requireSetup = false;
  int _currentIndex = 0;
  @override
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  late final List<Widget> _pages;

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
      if (allKeysExist) {
        _requireSetup = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return CircularProgressIndicator();
    }

    if (_requireSetup) {
      return AppSetup(
        this,
        appSetupFields,
        () => setState(() => _requireSetup = false),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_view_day),
            activeIcon: Icon(Icons.calendar_view_day_outlined),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf),
            label: 'PDF',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Audio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: 'Athlete Tracker',
          ),
        ],
      ),
    );
  }
}
