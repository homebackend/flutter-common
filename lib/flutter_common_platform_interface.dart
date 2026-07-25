import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_common_method_channel.dart';

abstract class FlutterCommonPlatform extends PlatformInterface {
  /// Constructs a FlutterCommonPlatform.
  FlutterCommonPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterCommonPlatform _instance = MethodChannelFlutterCommon();

  /// The default instance of [FlutterCommonPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterCommon].
  static FlutterCommonPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterCommonPlatform] when
  /// they register themselves.
  static set instance(FlutterCommonPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
