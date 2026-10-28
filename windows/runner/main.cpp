#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <cwctype>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>

#include "desktop_widget.h"
#include "flutter_window.h"
#include "utils.h"
#include "widget_diagnostics.h"

namespace {

std::wstring ProfileInstanceKey() {
  wchar_t executable[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, executable, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return {};
  const std::wstring path(executable, length);
  const auto separator = path.find_last_of(L"\\/");
  if (separator == std::wstring::npos) return {};
  const std::wstring directory = path.substr(0, separator);
  const bool portable = ::GetFileAttributesW(
      (directory + L"\\PORTABLE-MODE").c_str()) != INVALID_FILE_ATTRIBUTES;
  const DWORD root_size = ::GetEnvironmentVariableW(L"APPDATA", nullptr, 0);
  if (root_size < 2) return {};
  std::wstring root(root_size, L'\0');
  if (::GetEnvironmentVariableW(L"APPDATA", root.data(), root_size) == 0)
    return {};
  root.resize(root_size - 1);
  std::wstring profile = portable
      ? root + L"\\TodoPilot\\portable|" + directory
      : root + L"\\TodoPilot";
  std::transform(profile.begin(), profile.end(), profile.begin(),
                 [](wchar_t value) { return std::towlower(value); });
  uint64_t hash = 14695981039346656037ULL;
  for (const auto value : profile) {
    hash ^= static_cast<uint16_t>(value);
    hash *= 1099511628211ULL;
  }
  std::wostringstream output;
  output << std::hex << std::setw(16) << std::setfill(L'0') << hash;
  return output.str();
}

HWND FindProfileWindow(const std::wstring& key) {
  struct Search { std::wstring property; HWND found = nullptr; } search{
      L"TodorbitMain-" + key};
  ::EnumWindows([](HWND window, LPARAM parameter) -> BOOL {
    auto* target = reinterpret_cast<Search*>(parameter);
    if (::GetPropW(window, target->property.c_str()) != nullptr) {
      target->found = window;
      return FALSE;
    }
    return TRUE;
  }, reinterpret_cast<LPARAM>(&search));
  return search.found;
}

std::string ActivationCommand(const std::vector<std::string>& arguments) {
  const auto navigation = std::find(arguments.begin(), arguments.end(), "--navigate");
  if (navigation != arguments.end() && navigation + 1 != arguments.end() && (navigation+1)->size() <= 4096)
    return "navigate:" + *(navigation+1);
  const auto widget = std::find(arguments.begin(), arguments.end(), "--edit-widget");
  if (widget != arguments.end() && widget + 1 != arguments.end() &&
      (*(widget + 1) == "tasks" || *(widget + 1) == "calendar"))
    return "widget:" + *(widget + 1);
  const auto task = std::find(arguments.begin(), arguments.end(), "--task-id");
  if (task != arguments.end() && task + 1 != arguments.end())
    return "task:" + *(task + 1);
  if (std::find(arguments.begin(), arguments.end(), "--appearance") !=
      arguments.end()) return "appearance";
  return "open";
}

bool LaunchNativeWidgetCompanion() {
  wchar_t executable_buffer[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(
      nullptr, executable_buffer, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return false;
  }
  const std::wstring app_path(executable_buffer, length);
  const size_t separator = app_path.find_last_of(L"\\/");
  if (separator == std::wstring::npos) {
    return false;
  }
  const std::wstring directory = app_path.substr(0, separator);
  const std::wstring widget_path = directory + L"\\TodorbitWidget.exe";
  const DWORD widget_attributes = ::GetFileAttributesW(widget_path.c_str());
  if (widget_attributes == INVALID_FILE_ATTRIBUTES ||
      (widget_attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
    return false;
  }

  std::wstring command_line = L"\"" + widget_path +
      L"\" --widget --app-exe \"" + app_path + L"\"";
  std::vector<wchar_t> mutable_command(
      command_line.begin(), command_line.end());
  mutable_command.push_back(L'\0');
  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_info{};
  if (!::CreateProcessW(widget_path.c_str(), mutable_command.data(), nullptr,
                        nullptr, FALSE, 0, nullptr, directory.c_str(),
                        &startup_info, &process_info)) {
    return false;
  }
  ::CloseHandle(process_info.hThread);
  ::CloseHandle(process_info.hProcess);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::OleInitialize(nullptr);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // The helper owns this mutex while replacing the bundle. A normal launch
  // during that interval exits promptly so it cannot lock the executable.
  // The helper starts the updated app after installation.
  const bool update_restart =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--update-restart") != command_line_arguments.end();
  if (!update_restart) {
    HANDLE update_mutex = ::OpenMutexW(SYNCHRONIZE | MUTEX_MODIFY_STATE, FALSE,
                                      L"Local\\TodorbitUpdateHandoff");
    if (update_mutex == nullptr && ::GetLastError() != ERROR_FILE_NOT_FOUND) {
      ::OleUninitialize();
      return EXIT_FAILURE;
    }
    if (update_mutex != nullptr) {
      ::CloseHandle(update_mutex);
      ::OleUninitialize();
      return EXIT_SUCCESS;
    }
  }

  const bool native_widget_requested =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--widget") != command_line_arguments.end();
  if (native_widget_requested) {
    const bool launched = LaunchNativeWidgetCompanion();
    if (!launched) {
      ::MessageBoxW(nullptr,
                    L"The packaged native widget could not be started. "
                    L"Rebuild or reinstall Todorbit so "
                    L"TodorbitWidget.exe is beside Todorbit.exe.",
                    L"Todorbit widget", MB_OK | MB_ICONERROR);
    }
    ::OleUninitialize();
    return launched ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  const bool legacy_widget_mode =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--legacy-flutter-widget") != command_line_arguments.end();
  const bool diagnostics_requested = legacy_widget_mode &&
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--widget-diagnostics") != command_line_arguments.end();
  const std::wstring profile_key = legacy_widget_mode ? L"" : ProfileInstanceKey();
  HANDLE instance_mutex = nullptr;
  bool owns_instance = false;
  if (!legacy_widget_mode) {
    if (profile_key.empty()) {
      ::OleUninitialize();
      return EXIT_FAILURE;
    }
    const std::wstring mutex_name = L"Local\\TodorbitMain-" + profile_key;
    instance_mutex = ::CreateMutexW(nullptr, TRUE, mutex_name.c_str());
    if (instance_mutex == nullptr) {
      ::OleUninitialize();
      return EXIT_FAILURE;
    }
    owns_instance = ::GetLastError() != ERROR_ALREADY_EXISTS;
    if (!owns_instance) {
      const std::string command = ActivationCommand(command_line_arguments);
      for (int attempt = 0; attempt < 150; ++attempt) {
        if (const HWND existing = FindProfileWindow(profile_key)) {
          DWORD existing_process = 0;
          ::GetWindowThreadProcessId(existing, &existing_process);
          if (existing_process != 0) ::AllowSetForegroundWindow(existing_process);
          COPYDATASTRUCT packet{};
          packet.dwData = 0x54444F52;
          packet.cbData = static_cast<DWORD>(command.size());
          packet.lpData = const_cast<char*>(command.data());
          DWORD_PTR delivered = 0;
          const LRESULT sent = ::SendMessageTimeoutW(
              existing, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&packet),
              SMTO_ABORTIFHUNG, 2000, &delivered);
          ::CloseHandle(instance_mutex);
          ::OleUninitialize();
          return sent && delivered ? EXIT_SUCCESS : EXIT_FAILURE;
        }
        const DWORD acquired = ::WaitForSingleObject(instance_mutex, 0);
        if (acquired == WAIT_OBJECT_0 || acquired == WAIT_ABANDONED) {
          owns_instance = true;
          break;
        }
        ::Sleep(100);
      }
      if (!owns_instance) {
        ::CloseHandle(instance_mutex);
        ::OleUninitialize();
        return EXIT_FAILURE;
      }
    }
  }
  WidgetDiagnostics::Start(diagnostics_requested);
  WidgetDiagnostics::Log(legacy_widget_mode
                             ? L"legacy Flutter widget process starting"
                             : L"main application process starting");

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size = legacy_widget_mode
                               ? Win32Window::Size(360, 480)
                               : Win32Window::Size(1280, 720);
  const wchar_t* window_title =
      legacy_widget_mode ? L"Todorbit Legacy Widget" : L"Todorbit";
  if (!window.Create(window_title, origin, size)) {
    WidgetDiagnostics::Log(L"window creation failed");
    WidgetDiagnostics::Stop();
    if (owns_instance) ::ReleaseMutex(instance_mutex);
    if (instance_mutex) ::CloseHandle(instance_mutex);
    return EXIT_FAILURE;
  }
  const std::wstring profile_property = L"TodorbitMain-" + profile_key;
  if (owns_instance) ::SetPropW(window.GetHandle(), profile_property.c_str(),
                                reinterpret_cast<HANDLE>(1));
  WidgetDiagnostics::Snapshot(window.GetHandle(), nullptr, L"before desktop attachment");
  if (legacy_widget_mode && !AttachWidgetToDesktop(window.GetHandle())) {
    WidgetDiagnostics::Log(L"desktop attachment failed");
    WidgetDiagnostics::Stop();
    return EXIT_FAILURE;
  }
  WidgetDiagnostics::Snapshot(window.GetHandle(), nullptr, L"after desktop attachment");
  window.SetQuitOnClose(true);

  constexpr UINT_PTR kDiagnosticsTimer = 1;
  if (WidgetDiagnostics::Enabled()) {
    ::SetTimer(window.GetHandle(), kDiagnosticsTimer, 2000, nullptr);
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    if (WidgetDiagnostics::Enabled() && msg.hwnd == window.GetHandle() &&
        msg.message == WM_TIMER && msg.wParam == kDiagnosticsTimer) {
      WidgetDiagnostics::Poll(window.GetHandle());
      continue;
    }
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (WidgetDiagnostics::Enabled() && window.GetHandle()) {
    ::KillTimer(window.GetHandle(), kDiagnosticsTimer);
  }
  WidgetDiagnostics::Stop();
  if (owns_instance) {
    if (window.GetHandle()) ::RemovePropW(window.GetHandle(), profile_property.c_str());
    ::ReleaseMutex(instance_mutex);
  }
  if (instance_mutex) ::CloseHandle(instance_mutex);
  ::OleUninitialize();
  return EXIT_SUCCESS;
}
