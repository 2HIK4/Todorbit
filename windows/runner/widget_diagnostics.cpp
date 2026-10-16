#include "widget_diagnostics.h"

#ifdef _DEBUG

#include <commctrl.h>
#include <dwmapi.h>

#include <iomanip>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

namespace {
constexpr LONGLONG kMaxLogBytes = 2 * 1024 * 1024;
HANDLE g_file = INVALID_HANDLE_VALUE;
std::wstring g_path;
std::mutex g_mutex;
HWND g_view = nullptr;
std::wstring g_last_poll_state;

std::wstring HexHandle(HWND handle) {
  std::wostringstream out;
  out << L"0x" << std::hex << reinterpret_cast<UINT_PTR>(handle);
  return out.str();
}

std::wstring WindowClass(HWND window) {
  if (!window) return L"(none)";
  wchar_t name[256] = {};
  return ::GetClassNameW(window, name, 256) ? name : L"(unavailable)";
}

std::wstring WindowDetails(const wchar_t* label, HWND window) {
  std::wostringstream out;
  DWORD owner_process = 0;
  DWORD owner_thread = window ? ::GetWindowThreadProcessId(window, &owner_process) : 0;
  out << label << L"=" << HexHandle(window) << L" class=" << WindowClass(window)
      << L" pid=" << owner_process << L" tid=" << owner_thread;
  if (!window || !::IsWindow(window)) return out.str();

  const HWND parent = ::GetParent(window);
  const HWND owner = ::GetWindow(window, GW_OWNER);
  const HWND root = ::GetAncestor(window, GA_ROOT);
  const auto style = static_cast<UINT_PTR>(::GetWindowLongPtrW(window, GWL_STYLE));
  const auto ex_style = static_cast<UINT_PTR>(::GetWindowLongPtrW(window, GWL_EXSTYLE));
  DWORD cloaked = 0;
  const HRESULT cloak_result = ::DwmGetWindowAttribute(
      window, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  DWORD parent_process = 0;
  if (parent) ::GetWindowThreadProcessId(parent, &parent_process);
  out << L" parent=" << HexHandle(parent)
      << L" parentClass=" << WindowClass(parent)
      << L" parentPid=" << parent_process
      << L" owner=" << HexHandle(owner)
      << L" root=" << HexHandle(root)
      << L" style=0x" << std::hex << style
      << L" exStyle=0x" << ex_style << std::dec
      << L" enabled=" << ::IsWindowEnabled(window)
      << L" parentEnabled=" << (parent ? ::IsWindowEnabled(parent) : FALSE)
      << L" visible=" << ::IsWindowVisible(window)
      << L" minimized=" << ::IsIconic(window)
      << L" cloakHr=0x" << std::hex << static_cast<unsigned long>(cloak_result)
      << std::dec << L" cloaked=" << cloaked;
  return out.str();
}

std::wstring FocusDetails() {
  const HWND foreground = ::GetForegroundWindow();
  DWORD foreground_process = 0;
  const DWORD foreground_thread = foreground
      ? ::GetWindowThreadProcessId(foreground, &foreground_process) : 0;
  GUITHREADINFO local_info = {sizeof(GUITHREADINFO)};
  GUITHREADINFO foreground_info = {sizeof(GUITHREADINFO)};
  const BOOL local_ok = ::GetGUIThreadInfo(::GetCurrentThreadId(), &local_info);
  const BOOL foreground_ok = foreground_thread
      ? ::GetGUIThreadInfo(foreground_thread, &foreground_info) : FALSE;
  std::wostringstream out;
  out << L" focus=" << HexHandle(::GetFocus())
      << L" active=" << HexHandle(::GetActiveWindow())
      << L" foreground=" << HexHandle(foreground)
      << L" foregroundPid=" << foreground_process
      << L" foregroundTid=" << foreground_thread
      << L" localGuiOk=" << local_ok
      << L" localGuiFocus=" << HexHandle(local_info.hwndFocus)
      << L" localGuiActive=" << HexHandle(local_info.hwndActive)
      << L" foregroundGuiOk=" << foreground_ok
      << L" foregroundGuiFocus=" << HexHandle(foreground_info.hwndFocus)
      << L" foregroundGuiActive=" << HexHandle(foreground_info.hwndActive);
  return out.str();
}

const wchar_t* MessageName(UINT message) {
  switch (message) {
    case WM_ACTIVATE: return L"WM_ACTIVATE";
    case WM_ACTIVATEAPP: return L"WM_ACTIVATEAPP";
    case WM_MOUSEACTIVATE: return L"WM_MOUSEACTIVATE";
    case WM_SETFOCUS: return L"WM_SETFOCUS";
    case WM_KILLFOCUS: return L"WM_KILLFOCUS";
    case WM_KEYDOWN: return L"WM_KEYDOWN";
    case WM_CHAR: return L"WM_CHAR";
    case WM_SHOWWINDOW: return L"WM_SHOWWINDOW";
    case WM_WINDOWPOSCHANGED: return L"WM_WINDOWPOSCHANGED";
    case WM_SIZE: return L"WM_SIZE";
    case WM_SYSCOMMAND: return L"WM_SYSCOMMAND";
    default: return nullptr;
  }
}

void WriteLocked(const std::wstring& event) {
  if (g_file == INVALID_HANDLE_VALUE) return;
  LARGE_INTEGER size = {};
  if (::GetFileSizeEx(g_file, &size) && size.QuadPart >= kMaxLogBytes) {
    ::CloseHandle(g_file);
    ::MoveFileExW(g_path.c_str(), (g_path + L".old").c_str(),
                  MOVEFILE_REPLACE_EXISTING);
    g_file = ::CreateFileW(g_path.c_str(), FILE_APPEND_DATA | FILE_READ_ATTRIBUTES,
                           FILE_SHARE_READ,
                           nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (g_file == INVALID_HANDLE_VALUE) return;
  }
  SYSTEMTIME now = {};
  ::GetLocalTime(&now);
  std::wostringstream line;
  line << std::setfill(L'0') << std::setw(4) << now.wYear << L'-'
       << std::setw(2) << now.wMonth << L'-' << std::setw(2) << now.wDay << L' '
       << std::setw(2) << now.wHour << L':' << std::setw(2) << now.wMinute
       << L':' << std::setw(2) << now.wSecond << L'.' << std::setw(3)
       << now.wMilliseconds << L" pid=" << ::GetCurrentProcessId()
       << L" tid=" << ::GetCurrentThreadId() << L' ' << event << L"\r\n";
  const std::wstring wide = line.str();
  const int needed = ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                           static_cast<int>(wide.size()),
                                           nullptr, 0, nullptr, nullptr);
  if (needed <= 0) return;
  std::string utf8(static_cast<size_t>(needed), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()),
                        utf8.data(), needed, nullptr, nullptr);
  DWORD written = 0;
  ::WriteFile(g_file, utf8.data(), static_cast<DWORD>(utf8.size()), &written,
              nullptr);
}

LRESULT CALLBACK FlutterViewDiagnosticProc(HWND window, UINT message,
                                            WPARAM wparam, LPARAM lparam,
                                            UINT_PTR subclass_id,
                                            DWORD_PTR reference) {
  auto widget = reinterpret_cast<HWND>(reference);
  WidgetDiagnostics::WindowMessage(widget, window, window, message, wparam, lparam);
  if (message == WM_NCDESTROY) {
    ::RemoveWindowSubclass(window, FlutterViewDiagnosticProc, subclass_id);
  }
  return ::DefSubclassProc(window, message, wparam, lparam);
}
}  // namespace

namespace WidgetDiagnostics {
void Start(bool requested) {
  if (!requested) return;
  const DWORD length = ::GetEnvironmentVariableW(L"APPDATA", nullptr, 0);
  if (length == 0) return;
  std::vector<wchar_t> base(length);
  if (!::GetEnvironmentVariableW(L"APPDATA", base.data(), length)) return;
  const std::wstring app_dir = std::wstring(base.data()) + L"\\Life Manager";
  const std::wstring log_dir = app_dir + L"\\logs";
  ::CreateDirectoryW(app_dir.c_str(), nullptr);
  ::CreateDirectoryW(log_dir.c_str(), nullptr);
  g_path = log_dir + L"\\widget-diagnostics-" +
           std::to_wstring(::GetCurrentProcessId()) + L".log";
  g_file = ::CreateFileW(g_path.c_str(), FILE_APPEND_DATA | FILE_READ_ATTRIBUTES,
                         FILE_SHARE_READ,
                         nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  Log(L"diagnostics started; key values and text are never recorded");
}

bool Enabled() { return g_file != INVALID_HANDLE_VALUE; }

void Stop() {
  Log(L"diagnostics stopped");
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_file != INVALID_HANDLE_VALUE) {
    ::CloseHandle(g_file);
    g_file = INVALID_HANDLE_VALUE;
  }
}

void Log(const std::wstring& event) {
  std::lock_guard<std::mutex> lock(g_mutex);
  WriteLocked(event);
}

void Snapshot(HWND widget, HWND view, const wchar_t* reason) {
  if (g_file == INVALID_HANDLE_VALUE) return;
  Log(std::wstring(L"snapshot ") + reason + L" " +
      WindowDetails(L"widget", widget) + L" " +
      WindowDetails(L"view", view) + FocusDetails());
}

void WindowMessage(HWND widget, HWND view, HWND target, UINT message,
                   WPARAM wparam, LPARAM lparam) {
  if (g_file == INVALID_HANDLE_VALUE) return;
  const wchar_t* name = MessageName(message);
  if (!name) return;
  std::wostringstream out;
  out << (target == view ? L"view " : L"widget ") << name
      << L" hwnd=" << HexHandle(target);
  // Never log key codes, character codes, scan codes, or text input contents.
  if (message == WM_ACTIVATE) out << L" activation=" << LOWORD(wparam);
  if (message == WM_ACTIVATEAPP) out << L" active=" << (wparam != 0);
  if (message == WM_SHOWWINDOW) out << L" show=" << (wparam != 0);
  if (message == WM_SYSCOMMAND) out << L" command=0x" << std::hex
                                    << (wparam & 0xfff0);
  out << FocusDetails();
  Log(out.str());
  if (message == WM_ACTIVATE || message == WM_ACTIVATEAPP ||
      message == WM_SHOWWINDOW || message == WM_WINDOWPOSCHANGED ||
      message == WM_SYSCOMMAND || message == WM_SIZE) {
    Snapshot(widget, view, name);
  }
}

void AttachFlutterView(HWND widget, HWND view) {
  if (g_file == INVALID_HANDLE_VALUE || !view) return;
  g_view = view;
  const BOOL installed = ::SetWindowSubclass(
      view, FlutterViewDiagnosticProc, 1, reinterpret_cast<DWORD_PTR>(widget));
  Log(std::wstring(L"Flutter view subclass installed=") +
      (installed ? L"1" : L"0") + L" view=" + HexHandle(view));
  Snapshot(widget, view, L"view attached");
}

void Poll(HWND widget) {
  if (g_file == INVALID_HANDLE_VALUE) return;
  DWORD cloaked = 0;
  ::DwmGetWindowAttribute(widget, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  std::wostringstream state;
  state << HexHandle(::GetParent(widget)) << L' '
        << ::IsWindowVisible(widget) << L' ' << ::IsIconic(widget) << L' '
        << cloaked << L' ' << HexHandle(::GetForegroundWindow()) << L' '
        << HexHandle(::GetFocus()) << L' ' << HexHandle(::GetActiveWindow());
  if (state.str() != g_last_poll_state) {
    g_last_poll_state = state.str();
    Snapshot(widget, g_view, L"periodic state change");
  }
}
}  // namespace WidgetDiagnostics

#else
namespace WidgetDiagnostics {
void Start(bool) {}
bool Enabled() { return false; }
void Stop() {}
void Log(const std::wstring&) {}
void Snapshot(HWND, HWND, const wchar_t*) {}
void WindowMessage(HWND, HWND, HWND, UINT, WPARAM, LPARAM) {}
void AttachFlutterView(HWND, HWND) {}
void Poll(HWND) {}
}  // namespace WidgetDiagnostics
#endif
