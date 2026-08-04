import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RotateButton extends StatefulWidget {
  const RotateButton({super.key});
  @override
  State<RotateButton> createState() => _RotateButtonState();
}

class _RotateButtonState extends State<RotateButton> {
  bool isLandscape = false;

  void toggle() {
    setState(() => isLandscape = !isLandscape);

    if (isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  void unlock() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_landscape,
      ),
      onPressed: toggle,
    );
  }
}
