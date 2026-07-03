#include "shadowgate_tun/shadowgate_tun_plugin.h"

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <iphlpapi.h>
#include <netioapi.h>
#include <winsock2.h>
#include <windows.h>
#include <winioctl.h>

#include <codecvt>
#include <locale>
#include <sstream>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")

namespace {

// Wintun GUID
constexpr GUID WINTUN_ADAPTER_GUID = {
    0xdeadbeef, 0xbaad, 0xf00d,
    {0x0d, 0x15, 0x0a, 0x15, 0x0b, 0x0a, 0x0d, 0x15}};

const std::string kChannelName = "com.example.shadowgate/service";

using flutter::EncodableMap;
using flutter::EncodableValue;

// Helper to convert EncodableValue to string
std::string GetStringFromMap(const EncodableMap& map, const std::string& key) {
    auto it = map.find(EncodableValue(key));
    if (it != map.end() && std::holds_alternative<std::string>(it->second)) {
        return std::get<std::string>(it->second);
    }
    return "";
}

int GetIntFromMap(const EncodableMap& map, const std::string& key) {
    auto it = map.find(EncodableValue(key));
    if (it != map.end()) {
        if (std::holds_alternative<int>(it->second)) {
            return std::get<int>(it->second);
        }
        if (std::holds_alternative<double>(it->second)) {
            return static_cast<int>(std::get<double>(it->second));
        }
    }
    return 0;
}

bool GetBoolFromMap(const EncodableMap& map, const std::string& key) {
    auto it = map.find(EncodableValue(key));
    if (it != map.end() && std::holds_alternative<bool>(it->second)) {
        return std::get<bool>(it->second);
    }
    return false;
}

// Convert string to wide string
std::wstring ToWide(const std::string& str) {
    if (str.empty()) return std::wstring();
    int size = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
    std::wstring wstr(size, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &wstr[0], size);
    return wstr;
}

}  // namespace

namespace shadowgate_tun {

void ShadowgateTunPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), kChannelName,
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ShadowgateTunPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

ShadowgateTunPlugin::ShadowgateTunPlugin() {}

ShadowgateTunPlugin::~ShadowgateTunPlugin() {
  StopTun();
}

void ShadowgateTunPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const std::string &method = method_call.method_name();

  if (method == "startTun") {
    const auto *args = std::get_if<EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("INVALID_ARGS", "Invalid arguments");
      return;
    }

    std::string interface_name = GetStringFromMap(*args, "interfaceName");
    int mtu = GetIntFromMap(*args, "mtu");
    std::string dns = GetStringFromMap(*args, "dns");
    bool bypass_local = GetBoolFromMap(*args, "bypassLocalTraffic");

    if (interface_name.empty()) interface_name = "ShadowGate";
    if (mtu <= 0) mtu = 1500;
    if (dns.empty()) dns = "8.8.8.8";

    bool success = StartTun(interface_name, mtu, dns, bypass_local);
    result->Success(flutter::EncodableValue(success));

  } else if (method == "stopTun") {
    bool success = StopTun();
    result->Success(flutter::EncodableValue(success));

  } else if (method == "getTunStatus") {
    bool running = IsTunRunning();
    result->Success(flutter::EncodableValue(running));

  } else if (method == "requestVpnPermission") {
    // Windows doesn't need VPN permission like Android
    result->Success(flutter::EncodableValue(true));

  } else if (method == "checkAdminRights") {
    BOOL is_admin = FALSE;
    PSID admin_group = NULL;
    SID_IDENTIFIER_AUTHORITY nt_authority = SECURITY_NT_AUTHORITY;
    
    if (AllocateAndInitializeSid(&nt_authority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                  DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0,
                                  &admin_group)) {
      if (!CheckTokenMembership(NULL, admin_group, &is_admin)) {
        is_admin = FALSE;
      }
      FreeSid(admin_group);
    }
    
    result->Success(flutter::EncodableValue(is_admin == TRUE));

  } else {
    result->NotImplemented();
  }
}

bool ShadowgateTunPlugin::LoadWintun() {
  if (wintun_module_) return true;

  // Try to load wintun.dll from the app directory
  wintun_module_ = LoadLibraryExW(L"wintun.dll", NULL, LOAD_LIBRARY_SEARCH_APPLICATION_DIR);
  if (!wintun_module_) {
    // Try system path
    wintun_module_ = LoadLibraryW(L"wintun.dll");
  }
  if (!wintun_module_) return false;

  wintun_create_adapter_ = (WintunCreateAdapter)GetProcAddress(wintun_module_, "WintunCreateAdapter");
  wintun_open_adapter_ = (WintunOpenAdapter)GetProcAddress(wintun_module_, "WintunOpenAdapter");
  wintun_close_adapter_ = (WintunCloseAdapter)GetProcAddress(wintun_module_, "WintunCloseAdapter");
  wintun_create_session_ = (WintunCreateSession)GetProcAddress(wintun_module_, "WintunCreateSession");
  wintun_end_session_ = (WintunEndSession)GetProcAddress(wintun_module_, "WintunEndSession");
  wintun_get_read_wait_event_ = (WintunGetReadWaitEvent)GetProcAddress(wintun_module_, "WintunGetReadWaitEvent");
  wintun_receive_packet_ = (WintunReceivePacket)GetProcAddress(wintun_module_, "WintunReceivePacket");
  wintun_release_receive_packet_ = (WintunReleaseReceivePacket)GetProcAddress(wintun_module_, "WintunReleaseReceivePacket");
  wintun_allocate_send_packet_ = (WintunAllocateSendPacket)GetProcAddress(wintun_module_, "WintunAllocateSendPacket");
  wintun_send_packet_ = (WintunSendPacket)GetProcAddress(wintun_module_, "WintunSendPacket");
  wintun_get_adapter_luid_ = (WintunGetAdapterLuid)GetProcAddress(wintun_module_, "WintunGetAdapterLuid");
  wintun_get_running_driver_version_ = (WintunGetRunningDriverVersion)GetProcAddress(wintun_module_, "WintunGetRunningDriverVersion");

  if (!wintun_create_adapter_ || !wintun_close_adapter_ || 
      !wintun_create_session_ || !wintun_end_session_ ||
      !wintun_get_read_wait_event_ || !wintun_receive_packet_ ||
      !wintun_release_receive_packet_ || !wintun_allocate_send_packet_ ||
      !wintun_send_packet_) {
    FreeLibrary(wintun_module_);
    wintun_module_ = nullptr;
    return false;
  }

  return true;
}

bool ShadowgateTunPlugin::StartTun(const std::string& interface_name, int mtu,
                                    const std::string& dns, bool bypass_local) {
  if (is_running_) return true;

  if (!LoadWintun()) {
    return false;
  }

  std::wstring wname = ToWide(interface_name);
  
  // Create or open Wintun adapter
  wintun_adapter_ = wintun_create_adapter_(wname.c_str(), L"ShadowGate", &WINTUN_ADAPTER_GUID);
  if (!wintun_adapter_) {
    // Adapter might already exist, try to open it
    wintun_adapter_ = wintun_open_adapter_(wname.c_str());
  }
  if (!wintun_adapter_) return false;

  // Create session
  wintun_session_ = wintun_create_session_(wintun_adapter_, mtu);
  if (!wintun_session_) {
    wintun_close_adapter_(wintun_adapter_);
    wintun_adapter_ = nullptr;
    return false;
  }

  is_running_ = true;

  // Start read loop in separate thread
  tun_thread_ = new std::thread([this]() { TunReadLoop(); });

  // Set up IP configuration using netsh
  std::string cmd = "netsh interface ip set address name=\"" + interface_name + 
                    "\" source=static addr=10.0.0.1 mask=255.255.255.0 gateway=none";
  system(cmd.c_str());

  // Set DNS
  cmd = "netsh interface ip set dns name=\"" + interface_name + 
        "\" source=static addr=" + dns;
  system(cmd.c_str());

  return true;
}

bool ShadowgateTunPlugin::StopTun() {
  is_running_ = false;

  if (tun_thread_) {
    if (tun_thread_->joinable()) {
      tun_thread_->join();
    }
    delete tun_thread_;
    tun_thread_ = nullptr;
  }

  if (wintun_session_) {
    wintun_end_session_(wintun_session_);
    wintun_session_ = nullptr;
  }

  if (wintun_adapter_) {
    wintun_close_adapter_(wintun_adapter_);
    wintun_adapter_ = nullptr;
  }

  if (wintun_module_) {
    FreeLibrary(wintun_module_);
    wintun_module_ = nullptr;
  }

  return true;
}

bool ShadowgateTunPlugin::IsTunRunning() {
  return is_running_;
}

void ShadowgateTunPlugin::TunReadLoop() {
  if (!wintun_session_ || !wintun_get_read_wait_event_) return;

  HANDLE wait_event = wintun_get_read_wait_event_(wintun_session_);
  if (wait_event == NULL) return;

  while (is_running_) {
    DWORD wait_result = WaitForSingleObject(wait_event, 1000);
    if (wait_result == WAIT_FAILED) break;

    DWORD packet_size;
    BYTE* packet = (BYTE*)wintun_receive_packet_(wintun_session_, &packet_size);
    if (packet) {
      // Process incoming packet
      // In a full implementation, this would send the packet to Dart via EventChannel
      // For now, we just release it back
      wintun_release_receive_packet_(wintun_session_, packet);
    }
  }
}

}  // namespace shadowgate_tun