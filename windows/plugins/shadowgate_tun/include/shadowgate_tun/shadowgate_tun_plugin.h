#ifndef FLUTTER_PLUGIN_SHADOWGATE_TUN_PLUGIN_H_
#define FLUTTER_PLUGIN_SHADOWGATE_TUN_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <string>
#include <thread>
#include <atomic>
#include <winsock2.h>
#include <windows.h>

namespace shadowgate_tun {

class ShadowgateTunPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ShadowgateTunPlugin();
  virtual ~ShadowgateTunPlugin();

 private:
  // Wintun handles
  HMODULE wintun_module_ = nullptr;
  void* wintun_adapter_ = nullptr;
  void* wintun_session_ = nullptr;
  std::thread* tun_thread_ = nullptr;
  std::atomic<bool> is_running_{false};

  // Method call handler
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Wintun operations
  bool LoadWintun();
  bool StartTun(const std::string& interface_name, int mtu, 
                const std::string& dns, bool bypass_local);
  bool StopTun();
  bool IsTunRunning();
  void TunReadLoop();

  // Wintun function pointers (loaded dynamically from wintun.dll)
  using WintunCreateAdapter = void* (*)(const wchar_t*, const wchar_t*, const GUID*);
  using WintunOpenAdapter = void* (*)(const wchar_t*);
  using WintunCloseAdapter = void (*)(void*);
  using WintunCreateSession = void* (*)(void*, int);
  using WintunEndSession = void (*)(void*);
  using WintunGetReadWaitEvent = HANDLE (*)(void*);
  using WintunReceivePacket = void* (*)(void*, DWORD*);
  using WintunReleaseReceivePacket = void (*)(void*, const void*);
  using WintunAllocateSendPacket = void* (*)(void*, DWORD);
  using WintunSendPacket = void (*)(void*, const void*);
  using WintunGetAdapterLuid = void (*)(void*, void*);
  using WintunGetRunningDriverVersion = DWORD (*)();

  WintunCreateAdapter wintun_create_adapter_ = nullptr;
  WintunOpenAdapter wintun_open_adapter_ = nullptr;
  WintunCloseAdapter wintun_close_adapter_ = nullptr;
  WintunCreateSession wintun_create_session_ = nullptr;
  WintunEndSession wintun_end_session_ = nullptr;
  WintunGetReadWaitEvent wintun_get_read_wait_event_ = nullptr;
  WintunReceivePacket wintun_receive_packet_ = nullptr;
  WintunReleaseReceivePacket wintun_release_receive_packet_ = nullptr;
  WintunAllocateSendPacket wintun_allocate_send_packet_ = nullptr;
  WintunSendPacket wintun_send_packet_ = nullptr;
  WintunGetAdapterLuid wintun_get_adapter_luid_ = nullptr;
  WintunGetRunningDriverVersion wintun_get_running_driver_version_ = nullptr;
};

}  // namespace shadowgate_tun

#endif  // FLUTTER_PLUGIN_SHADOWGATE_TUN_PLUGIN_H_