#include "flutter_window.h"

#include <optional>
#include <shobjidl.h>
#include <shellapi.h>
#include <wrl/client.h>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"
#include "widget_diagnostics.h"

namespace {

void ShowFileDialog(
    HWND owner, bool save, bool any_file, bool folder,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Microsoft::WRL::ComPtr<IFileDialog> dialog;
  HRESULT status = ::CoCreateInstance(
      save ? CLSID_FileSaveDialog : CLSID_FileOpenDialog, nullptr,
      CLSCTX_INPROC_SERVER, IID_PPV_ARGS(dialog.GetAddressOf()));
  if (FAILED(status)) {
    result->Error("dialog_failed", "Could not open the Windows file dialog");
    return;
  }
  COMDLG_FILTERSPEC filter{L"SQLite database (*.sqlite)", L"*.sqlite"};
  if (!any_file && !folder) status = dialog->SetFileTypes(1, &filter);
  if (SUCCEEDED(status)) {
    DWORD options = 0;
    status = dialog->GetOptions(&options);
    if (SUCCEEDED(status)) {
      status = dialog->SetOptions(options | FOS_FORCEFILESYSTEM |
                                  (folder ? FOS_PICKFOLDERS : 0) |
                                  (save ? FOS_OVERWRITEPROMPT : FOS_FILEMUSTEXIST));
    }
  }
  if (SUCCEEDED(status) && save) {
    status = dialog->SetFileName(L"life-manager-export.sqlite");
    if (SUCCEEDED(status)) status = dialog->SetDefaultExtension(L"sqlite");
  }
  if (SUCCEEDED(status)) status = dialog->Show(owner);
  if (status == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    result->Success();
    return;
  }
  if (FAILED(status)) {
    result->Error("dialog_failed", "Windows could not select a database file");
    return;
  }
  Microsoft::WRL::ComPtr<IShellItem> item;
  status = dialog->GetResult(item.GetAddressOf());
  PWSTR selected = nullptr;
  if (SUCCEEDED(status)) status = item->GetDisplayName(SIGDN_FILESYSPATH, &selected);
  if (FAILED(status) || selected == nullptr) {
    result->Error("dialog_failed", "Windows did not return a file path");
    return;
  }
  const std::string path = Utf8FromUtf16(selected);
  ::CoTaskMemFree(selected);
  if (path.empty()) {
    result->Error("dialog_failed", "The selected file path could not be read");
    return;
  }
  result->Success(flutter::EncodableValue(path));
}

std::wstring Utf16FromUtf8(const std::string& input) {
  const int size = ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         input.c_str(), -1, nullptr, 0);
  if (size <= 1) return {};
  std::wstring output(size, L'\0');
  if (::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                            input.c_str(), -1, output.data(), size) == 0) {
    return {};
  }
  output.pop_back();
  return output;
}

bool DecodeColor(const std::string& text, COLORREF* color) {
  if (text.size() != 6) return false;
  try {
    size_t consumed = 0;
    const auto value = std::stoul(text, &consumed, 16);
    if (consumed != 6 || value > 0xFFFFFF) return false;
    *color = RGB((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
    return true;
  } catch (...) {
    return false;
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  file_dialog_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "life_manager/file_dialog", &flutter::StandardMethodCodec::GetInstance());
  file_dialog_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "openDatabase") {
          ShowFileDialog(GetHandle(), false, false, false, std::move(result));
        } else if (call.method_name() == "saveDatabase") {
          ShowFileDialog(GetHandle(), true, false, false, std::move(result));
        } else if (call.method_name() == "openFile") {
          ShowFileDialog(GetHandle(), false, true, false, std::move(result));
        } else if (call.method_name() == "openFolder") {
          ShowFileDialog(GetHandle(), false, true, true, std::move(result));
        } else if (call.method_name() == "openResource") {
          const auto* value = std::get_if<std::string>(call.arguments());
          if (value == nullptr) {
            result->Error("invalid_path", "A resource path is required");
            return;
          }
          const std::wstring target = Utf16FromUtf8(*value);
          if (target.empty()) {
            result->Error("invalid_path", "The resource path could not be read");
            return;
          }
          const auto opened = reinterpret_cast<INT_PTR>(
              ::ShellExecuteW(GetHandle(), L"open", target.c_str(),
                              nullptr, nullptr, SW_SHOWNORMAL));
          if (opened <= 32) {
            result->Error("open_failed", "Windows could not open the resource");
            return;
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  window_theme_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "life_manager/window_theme", &flutter::StandardMethodCodec::GetInstance());
  window_theme_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "set") {
          result->NotImplemented();
          return;
        }
        const auto* values = std::get_if<flutter::EncodableList>(call.arguments());
        if (values == nullptr || values->size() != 3) {
          result->Error("invalid_theme", "Expected brightness and two RGB colors");
          return;
        }
        const auto* brightness = std::get_if<std::string>(&(*values)[0]);
        const auto* background = std::get_if<std::string>(&(*values)[1]);
        const auto* foreground = std::get_if<std::string>(&(*values)[2]);
        COLORREF background_color, foreground_color;
        if (brightness == nullptr || background == nullptr ||
            foreground == nullptr ||
            (*brightness != "dark" && *brightness != "light") ||
            !DecodeColor(*background, &background_color) ||
            !DecodeColor(*foreground, &foreground_color)) {
          result->Error("invalid_theme", "Invalid caption theme value");
          return;
        }
        SetCaptionTheme(*brightness == "dark", background_color,
                        foreground_color);
        result->Success();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    file_dialog_channel_.reset();
    window_theme_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      if (message == WM_SETFOCUS) {
        WidgetDiagnostics::Log(L"Flutter engine handled outer WM_SETFOCUS");
      }
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  if (message == WM_SETFOCUS) {
    WidgetDiagnostics::Log(L"outer WM_SETFOCUS forwarded to runner");
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
