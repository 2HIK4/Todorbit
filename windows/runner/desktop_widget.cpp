#include "desktop_widget.h"

bool AttachWidgetToDesktop(HWND widget) {
  HWND desktop = ::GetDesktopWindow();
  if (!widget || !desktop) {
    return false;
  }

  const LONG_PTR original_style = ::GetWindowLongPtr(widget, GWL_STYLE);
  const LONG_PTR child_style =
      (original_style & ~static_cast<LONG_PTR>(WS_OVERLAPPEDWINDOW | WS_POPUP)) |
      WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
  ::SetWindowLongPtr(widget, GWL_STYLE, child_style);
  ::SetLastError(0);
  ::SetParent(widget, desktop);
  if (::GetParent(widget) != desktop) {
    ::SetWindowLongPtr(widget, GWL_STYLE, original_style);
    return false;
  }

  ::SetWindowPos(widget, nullptr, 24, 24, 360, 480,
                 SWP_NOZORDER | SWP_FRAMECHANGED | SWP_NOACTIVATE);
  return true;
}
