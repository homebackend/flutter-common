#include "flutter_common_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

#include <window_manager/window_manager_plugin.h>

namespace flutter_common {

void RegisterAdditionalWindowsPlugins(flutter::PluginRegistry *registry) {
  auto *window_manager_registrar =
      registry->GetRegistrarForPlugin("WindowManagerPlugin");

  if (window_manager_registrar != nullptr) {
    WindowManagerPluginRegisterWithRegistrar(window_manager_registrar);
  }
}

// static
void FlutterCommonPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  flutter::PluginRegistry *registry = registrar->GetRegistry();
  RegisterAdditionalWindowsPlugins(registry);

  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_common",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterCommonPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterCommonPlugin::FlutterCommonPlugin() {}

FlutterCommonPlugin::~FlutterCommonPlugin() {}

void FlutterCommonPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else {
    result->NotImplemented();
  }
}

} // namespace flutter_common
