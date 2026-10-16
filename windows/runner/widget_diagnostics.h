#ifndef RUNNER_WIDGET_DIAGNOSTICS_H_
#define RUNNER_WIDGET_DIAGNOSTICS_H_

#include <windows.h>

#include <string>

// Debug-build-only, opt-in diagnostics. Never records key values or task text.
namespace WidgetDiagnostics {
void Start(bool requested);
bool Enabled();
void Stop();
void Log(const std::wstring& event);
void Snapshot(HWND widget, HWND view, const wchar_t* reason);
void WindowMessage(HWND widget, HWND view, HWND target, UINT message,
                   WPARAM wparam, LPARAM lparam);
void AttachFlutterView(HWND widget, HWND view);
void Poll(HWND widget);
}  // namespace WidgetDiagnostics

#endif  // RUNNER_WIDGET_DIAGNOSTICS_H_
