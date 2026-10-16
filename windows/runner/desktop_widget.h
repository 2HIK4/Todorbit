#ifndef RUNNER_DESKTOP_WIDGET_H_
#define RUNNER_DESKTOP_WIDGET_H_

#include <windows.h>

// Experimental supported-API attempt. Does not use Explorer's undocumented
// WorkerW messages. Returns false rather than displaying a normal window.
bool AttachWidgetToDesktop(HWND widget);

#endif  // RUNNER_DESKTOP_WIDGET_H_
