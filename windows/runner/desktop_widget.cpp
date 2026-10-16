#include "desktop_widget.h"

#include <sstream>

#include "widget_diagnostics.h"

bool AttachWidgetToDesktop(HWND widget) {
  HWND desktop = ::GetDesktopWindow();
  WidgetDiagnostics::Snapshot(widget, nullptr, L"SetParent begin");
  if (!widget || !desktop) {
    WidgetDiagnostics::Log(L"SetParent aborted: missing widget or desktop HWND");
    return false;
  }

  const LONG_PTR original_style = ::GetWindowLongPtr(widget, GWL_STYLE);
  const LONG_PTR child_style =
      (original_style & ~static_cast<LONG_PTR>(WS_OVERLAPPEDWINDOW | WS_POPUP)) |
      WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
  ::SetLastError(0);
  ::SetWindowLongPtr(widget, GWL_STYLE, child_style);
  const DWORD style_error = ::GetLastError();
  ::SetLastError(0);
  const HWND previous_parent = ::SetParent(widget, desktop);
  const DWORD parent_error = ::GetLastError();
  {
    std::wostringstream result;
    result << L"SetParent previous=" << previous_parent
           << L" requested=" << desktop
           << L" actual=" << ::GetParent(widget)
           << L" styleError=" << style_error
           << L" parentError=" << parent_error;
    WidgetDiagnostics::Log(result.str());
  }
  if (::GetParent(widget) != desktop) {
    ::SetWindowLongPtr(widget, GWL_STYLE, original_style);
    WidgetDiagnostics::Snapshot(widget, nullptr, L"SetParent rollback");
    return false;
  }

  ::SetLastError(0);
  const BOOL positioned = ::SetWindowPos(
      widget, nullptr, 24, 24, 360, 480,
      SWP_NOZORDER | SWP_FRAMECHANGED | SWP_NOACTIVATE);
  WidgetDiagnostics::Log(std::wstring(L"SetWindowPos success=") +
                         (positioned ? L"1" : L"0") + L" error=" +
                         std::to_wstring(::GetLastError()));
  WidgetDiagnostics::Snapshot(widget, nullptr, L"SetWindowPos after attachment");
  return true;
}
