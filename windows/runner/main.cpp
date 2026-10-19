#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "desktop_widget.h"
#include "flutter_window.h"
#include "utils.h"
#include "widget_diagnostics.h"

namespace {

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
  const std::wstring widget_path = directory + L"\\TodoPilotWidget.exe";
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
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  const bool native_widget_requested =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--widget") != command_line_arguments.end();
  if (native_widget_requested) {
    const bool launched = LaunchNativeWidgetCompanion();
    if (!launched) {
      ::MessageBoxW(nullptr,
                    L"The packaged native widget could not be started. "
                    L"Rebuild or reinstall TodoPilot so "
                    L"TodoPilotWidget.exe is beside TodoPilot.exe.",
                    L"TodoPilot widget", MB_OK | MB_ICONERROR);
    }
    ::CoUninitialize();
    return launched ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  const bool legacy_widget_mode =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--legacy-flutter-widget") != command_line_arguments.end();
  const bool diagnostics_requested = legacy_widget_mode &&
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--widget-diagnostics") != command_line_arguments.end();
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
      legacy_widget_mode ? L"TodoPilot Legacy Widget" : L"TodoPilot";
  if (!window.Create(window_title, origin, size)) {
    WidgetDiagnostics::Log(L"window creation failed");
    WidgetDiagnostics::Stop();
    return EXIT_FAILURE;
  }
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
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
