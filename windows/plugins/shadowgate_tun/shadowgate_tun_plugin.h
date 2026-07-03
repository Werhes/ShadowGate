#ifndef FLUTTER_PLUGIN_SHADOWGATE_TUN_PLUGIN_H_
#define FLUTTER_PLUGIN_SHADOWGATE_TUN_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace shadowgate_tun {

class ShadowgateTunPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ShadowgateTunPlugin();

  virtual ~ShadowgateTunPlugin();

 private:
  // Called when a method is called on this plugin's channel
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace shadowgate_tun

#endif  // FLUTTER_PLUGIN_SHADOWGATE_TUN_PLUGIN_H_