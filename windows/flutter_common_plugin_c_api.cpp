#include "include/flutter_common/flutter_common_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_common_plugin.h"

void FlutterCommonPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_common::FlutterCommonPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
