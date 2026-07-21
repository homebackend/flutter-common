/*
 * Copyright (c) 2026 Neeraj Jakhar
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'package:flutter/material.dart';
import 'package:flutter_common/mixin/main_config_manager.dart';

class AppSetupField {
  String storageKey;
  String labelText;
  bool? emptyAllowed;
  bool obscureText;

  AppSetupField(
    this.storageKey,
    this.labelText,
    this.obscureText, {
    this.emptyAllowed,
  });
}

class AppSetup extends StatefulWidget {
  final MainConfigManager configManager;
  final List<AppSetupField> setupFields;
  final void Function() onImport;
  const AppSetup(
    this.configManager,
    this.setupFields,
    this.onImport, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _AppSetupState();
}

class _AppSetupState extends State<AppSetup> {
  final List<TextEditingController> _textControllers = [];
  List<String?> _errors = [];

  @override
  void initState() {
    super.initState();

    _textControllers.addAll(
      widget.setupFields.map((_) => TextEditingController()),
    );
    _errors.addAll(widget.setupFields.map((_) => null));
  }

  @override
  void dispose() {
    for (var c in _textControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ...widget.setupFields.asMap().entries.expand((e) {
                return [
                  TextField(
                    controller: _textControllers[e.key],
                    decoration: InputDecoration(
                      labelText: e.value.labelText,
                      border: const OutlineInputBorder(),
                      errorText: _errors[e.key],
                    ),
                    obscureText: e.value.obscureText,
                  ),
                  if (e.key < widget.setupFields.length - 1)
                    const SizedBox(height: 12),
                ];
              }),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final values = Map.fromEntries(
                    widget.setupFields.asMap().entries.map(
                      (e) => MapEntry(
                        e.value.storageKey,
                        _textControllers[e.key].text.trim(),
                      ),
                    ),
                  );

                  final emptyAllowed = Map.fromEntries(
                    widget.setupFields.map(
                      (f) => MapEntry(f.storageKey, f.emptyAllowed == true),
                    ),
                  );

                  setState(() {
                    _errors = values.entries
                        .map(
                          (e) => !emptyAllowed[e.key]! && e.value.isEmpty
                              ? 'Required'
                              : null,
                        )
                        .toList();
                  });

                  if (values.entries.any(
                    (e) => !emptyAllowed[e.key]! && e.value.isEmpty,
                  )) {
                    return;
                  }

                  widget.configManager.setConfigValues(values);
                },
                child: const Text('Complete Setup'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_present),
                label: const Text('Import Configuration File'),
                onPressed: () async {
                  final msg = await widget.configManager
                      .importSystemPreferences();
                  if (msg != null && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  } else {
                    widget.onImport();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
