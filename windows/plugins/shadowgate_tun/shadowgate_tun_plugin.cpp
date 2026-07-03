#include "include/shadowgate_tun/shadowgate_tun_plugin.h"

// This file is the entry point for the plugin.
// shadowgate_tun_plugin.cpp in src/ contains the actual implementation.

namespace shadowgate_tun {

void ShadowgateTunPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.example.shadowgate/service",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ShadowgateTunPlugin>();

  auto* plugin_ptr = plugin.get();
  channel->SetMethodCallHandler(
      [plugin_ptr](const auto &call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

}  // namespace shadowgate_tun

// Flutter plugin registration function
extern "C" __declspec(dllexport) void RegisterPlugins(
    flutter::PluginRegistrarWindows *registrar) {
  shadowgate_tun::ShadowgateTunPlugin::RegisterWithRegistrar(registrar);
}