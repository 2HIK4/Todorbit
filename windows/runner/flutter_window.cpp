#include "flutter_window.h"

#include <algorithm>
#include <cwctype>
#include <functional>
#include <optional>
#include <stdexcept>
#include <shobjidl.h>
#include <shellapi.h>
#include <spellcheck.h>
#include <wrl/client.h>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"
#include "widget_diagnostics.h"

namespace {

// Use the existing companion pipe directly. Preview never launches a process
// or writes a file. Bound waits so a stopped companion cannot freeze settings.
bool SendWidgetPreview(const std::string& suffix, const std::string& message) {
  if (suffix.size() != 16 ||
      suffix.find_first_not_of("0123456789abcdef") != std::string::npos ||
      message.size() > 65536 ||
      message.rfind("preview-configuration ", 0) != 0 ||
      message.find_first_of("\r\n") != std::string::npos) return false;
  const std::string pipe_name =
      "\\\\.\\pipe\\LifeManager.NativeWidget.Commands.v2." + suffix;
  if (!WaitNamedPipeA(pipe_name.c_str(), 50)) return false;
  HANDLE pipe = CreateFileA(pipe_name.c_str(), GENERIC_WRITE, 0, nullptr,
      OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
  if (pipe == INVALID_HANDLE_VALUE) return false;
  OVERLAPPED operation{};
  operation.hEvent = CreateEvent(nullptr, TRUE, FALSE, nullptr);
  if (!operation.hEvent) { CloseHandle(pipe); return false; }
  const std::string payload = message + "\n";
  DWORD written = 0;
  BOOL sent = WriteFile(pipe, payload.data(), static_cast<DWORD>(payload.size()),
                       &written, &operation);
  if (!sent && GetLastError() == ERROR_IO_PENDING) {
    if (WaitForSingleObject(operation.hEvent, 100) != WAIT_OBJECT_0) {
      CancelIoEx(pipe, &operation);
    }
    sent = GetOverlappedResult(pipe, &operation, &written, TRUE);
  }
  CloseHandle(operation.hEvent);
  CloseHandle(pipe);
  return sent && written == payload.size();
}

class ExplorerFileDropTarget final : public IDropTarget {
 public:
  using Callback = std::function<void(const char*, POINT,
                                      const std::vector<std::string>&)>;
  explicit ExplorerFileDropTarget(Callback callback)
      : callback_(std::move(callback)) {}

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void** value) override {
    if (value == nullptr) return E_POINTER;
    if (id != IID_IUnknown && id != IID_IDropTarget) {
      *value = nullptr;
      return E_NOINTERFACE;
    }
    *value = static_cast<IDropTarget*>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override {
    return static_cast<ULONG>(::InterlockedIncrement(&refs_));
  }
  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG remaining = static_cast<ULONG>(::InterlockedDecrement(&refs_));
    if (remaining == 0) delete this;
    return remaining;
  }
  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data, DWORD,
      POINTL position, DWORD* effect) override {
    FORMATETC format{CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    accepts_ = data != nullptr && SUCCEEDED(data->QueryGetData(&format));
    *effect = accepts_ ? DROPEFFECT_COPY : DROPEFFECT_NONE;
    if (accepts_) callback_("hover", POINT{position.x, position.y}, {});
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE DragOver(DWORD, POINTL position,
      DWORD* effect) override {
    *effect = accepts_ ? DROPEFFECT_COPY : DROPEFFECT_NONE;
    if (accepts_) callback_("hover", POINT{position.x, position.y}, {});
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE DragLeave() override {
    callback_("leave", POINT{}, {});
    accepts_ = false;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data, DWORD,
      POINTL position, DWORD* effect) override {
    *effect = DROPEFFECT_NONE;
    callback_("leave", POINT{}, {});
    if (!accepts_ || data == nullptr) return S_OK;
    accepts_ = false;
    FORMATETC format{CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    STGMEDIUM medium{};
    if (FAILED(data->GetData(&format, &medium))) return S_OK;
    std::vector<std::string> paths;
    const HDROP files = static_cast<HDROP>(medium.hGlobal);
    const UINT count = ::DragQueryFileW(files, 0xFFFFFFFF, nullptr, 0);
    for (UINT index = 0; index < count && index < 100; ++index) {
      const UINT size = ::DragQueryFileW(files, index, nullptr, 0);
      if (size == 0 || size > 32767) continue;
      std::wstring path(size + 1, L'\0');
      ::DragQueryFileW(files, index, path.data(), size + 1);
      path.resize(size);
      paths.push_back(Utf8FromUtf16(path.c_str()));
    }
    ::ReleaseStgMedium(&medium);
    if (!paths.empty()) {
      callback_("drop", POINT{position.x, position.y}, paths);
      *effect = DROPEFFECT_COPY;
    }
    return S_OK;
  }

 private:
  ~ExplorerFileDropTarget() = default;
  LONG refs_ = 1;
  Callback callback_;
  bool accepts_ = false;
};

void ShowFileDialog(
    HWND owner, bool save, bool any_file, bool folder,
    bool settings_json,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Microsoft::WRL::ComPtr<IFileDialog> dialog;
  HRESULT status = ::CoCreateInstance(
      save ? CLSID_FileSaveDialog : CLSID_FileOpenDialog, nullptr,
      CLSCTX_INPROC_SERVER, IID_PPV_ARGS(dialog.GetAddressOf()));
  if (FAILED(status)) {
    result->Error("dialog_failed", "Could not open the Windows file dialog");
    return;
  }
  COMDLG_FILTERSPEC filter = settings_json
      ? COMDLG_FILTERSPEC{L"Todorbit settings (*.json)", L"*.json"}
      : COMDLG_FILTERSPEC{L"SQLite database (*.sqlite)", L"*.sqlite"};
  if ((!any_file && !folder) || settings_json) status = dialog->SetFileTypes(1, &filter);
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
    status = dialog->SetFileName(settings_json ? L"Todorbit-settings.json" : L"life-manager-export.sqlite");
    if (SUCCEEDED(status)) status = dialog->SetDefaultExtension(settings_json ? L"json" : L"sqlite");
  }
  if (SUCCEEDED(status)) status = dialog->Show(owner);
  if (status == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    result->Success();
    return;
  }
  if (FAILED(status)) {
    result->Error("dialog_failed", settings_json
        ? "Windows could not select a settings file"
        : "Windows could not select a database file");
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

flutter::EncodableList CheckSpelling(const std::string& input) {
  const std::wstring original = Utf16FromUtf8(input);
  if (original.empty()) return {};
  if (original.size() > 20000) throw std::runtime_error("Text is too long for spelling review");
  std::wstring checked = original;
  size_t cursor = 0;
  while (cursor < checked.size()) {
    while (cursor < checked.size() && std::iswspace(checked[cursor])) ++cursor;
    const size_t start = cursor;
    while (cursor < checked.size() && !std::iswspace(checked[cursor])) ++cursor;
    if (start == cursor) break;
    const std::wstring token = checked.substr(start, cursor - start);
    bool technical = token.find(L"://") != std::wstring::npos ||
        token.find(L'\\') != std::wstring::npos ||
        token.find(L'/') != std::wstring::npos ||
        token.find(L'_') != std::wstring::npos ||
        token.find(L'@') != std::wstring::npos;
    for (size_t index = 0; index < token.size(); ++index) {
      technical |= std::iswdigit(token[index]) != 0;
      if (index > 0 && std::iswlower(token[index - 1]) &&
          std::iswupper(token[index])) technical = true;
    }
    if (technical) std::fill(checked.begin() + start, checked.begin() + cursor, L' ');
  }
  Microsoft::WRL::ComPtr<ISpellCheckerFactory> factory;
  HRESULT status = ::CoCreateInstance(__uuidof(SpellCheckerFactory), nullptr,
      CLSCTX_INPROC_SERVER, IID_PPV_ARGS(factory.GetAddressOf()));
  if (FAILED(status)) throw std::runtime_error("Windows spell checking is unavailable");
  BOOL supported = FALSE;
  status = factory->IsSupported(L"en-US", &supported);
  if (FAILED(status) || !supported) throw std::runtime_error("English (United States) spelling is unavailable in Windows");
  Microsoft::WRL::ComPtr<ISpellChecker> checker;
  status = factory->CreateSpellChecker(L"en-US", checker.GetAddressOf());
  if (FAILED(status)) throw std::runtime_error("Windows spell checking is unavailable");
  Microsoft::WRL::ComPtr<IEnumSpellingError> errors;
  status = checker->Check(checked.c_str(), errors.GetAddressOf());
  if (FAILED(status)) throw std::runtime_error("Windows spell checking failed");
  flutter::EncodableList found;
  for (int count = 0; count < 100; ++count) {
    Microsoft::WRL::ComPtr<ISpellingError> error;
    if (errors->Next(error.GetAddressOf()) != S_OK || !error) break;
    ULONG start = 0, length = 0;
    if (FAILED(error->get_StartIndex(&start)) ||
        FAILED(error->get_Length(&length)) || length == 0 ||
        start + length > original.size()) continue;
    const std::wstring word = original.substr(start, length);
    Microsoft::WRL::ComPtr<IEnumString> suggestions;
    flutter::EncodableList options;
    if (SUCCEEDED(checker->Suggest(word.c_str(), suggestions.GetAddressOf()))) {
      for (int i = 0; i < 5; ++i) {
        LPOLESTR suggestion = nullptr;
        ULONG fetched = 0;
        if (suggestions->Next(1, &suggestion, &fetched) != S_OK ||
            fetched == 0) break;
        options.emplace_back(Utf8FromUtf16(suggestion));
        ::CoTaskMemFree(suggestion);
      }
    }
    found.emplace_back(flutter::EncodableMap{
        {flutter::EncodableValue("start"), flutter::EncodableValue(static_cast<int>(start))},
        {flutter::EncodableValue("length"), flutter::EncodableValue(static_cast<int>(length))},
        {flutter::EncodableValue("word"), flutter::EncodableValue(Utf8FromUtf16(word.c_str()))},
        {flutter::EncodableValue("suggestions"), flutter::EncodableValue(options)}});
  }
  return found;
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

void FlutterWindow::DeliverActivation() {
  if (!activation_ready_ || pending_activation_.empty() ||
      !activation_channel_) return;
  activation_channel_->InvokeMethod(
      "activate", std::make_unique<flutter::EncodableValue>(pending_activation_));
  pending_activation_.clear();
}

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
  widget_preview_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "life_manager/widget_preview", &flutter::StandardMethodCodec::GetInstance());
  widget_preview_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "send") { result->NotImplemented(); return; }
        const auto* values = std::get_if<flutter::EncodableList>(call.arguments());
        if (!values || values->size() != 2) {
          result->Error("invalid_preview", "Invalid preview message"); return;
        }
        const auto* suffix = std::get_if<std::string>(&(*values)[0]);
        const auto* message = std::get_if<std::string>(&(*values)[1]);
        result->Success(flutter::EncodableValue(
            suffix && message && SendWidgetPreview(*suffix, *message)));
      });
  activation_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "life_manager/activation", &flutter::StandardMethodCodec::GetInstance());
  activation_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "ready") {
          result->NotImplemented();
          return;
        }
        activation_ready_ = true;
        result->Success();
        DeliverActivation();
      });
  spell_check_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "life_manager/spell_check", &flutter::StandardMethodCodec::GetInstance());
  spell_check_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "check") {
          result->NotImplemented();
          return;
        }
        const auto* input = std::get_if<std::string>(call.arguments());
        if (!input || input->size() > 80000) {
          result->Error("invalid_text", "Text is unavailable or too long");
          return;
        }
        try {
          result->Success(flutter::EncodableValue(CheckSpelling(*input)));
        } catch (const std::exception& error) {
          result->Error("spell_check_unavailable", error.what());
        }
      });
  file_drop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "life_manager/file_drop", &flutter::StandardMethodCodec::GetInstance());
  file_drop_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "available") {
          result->Success(flutter::EncodableValue(file_drop_available_));
        } else {
          result->NotImplemented();
        }
      });
  file_dialog_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "life_manager/file_dialog", &flutter::StandardMethodCodec::GetInstance());
  file_dialog_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "openDatabase") {
          ShowFileDialog(GetHandle(), false, false, false, false, std::move(result));
        } else if (call.method_name() == "saveDatabase") {
          ShowFileDialog(GetHandle(), true, false, false, false, std::move(result));
        } else if (call.method_name() == "openSettings") {
          ShowFileDialog(GetHandle(), false, false, false, true, std::move(result));
        } else if (call.method_name() == "saveSettings") {
          ShowFileDialog(GetHandle(), true, false, false, true, std::move(result));
        } else if (call.method_name() == "openFile") {
          ShowFileDialog(GetHandle(), false, true, false, false, std::move(result));
        } else if (call.method_name() == "openFolder") {
          ShowFileDialog(GetHandle(), false, true, true, false, std::move(result));
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
        if (call.method_name() == "getVersion") {
          result->Success(flutter::EncodableValue(std::string(FLUTTER_VERSION)));
          return;
        }
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
  file_drop_window_ = flutter_controller_->view()->GetNativeWindow();
  file_drop_target_ = new ExplorerFileDropTarget(
      [this](const char* event, POINT position,
             const std::vector<std::string>& paths) {
        if (!file_drop_channel_) return;
        flutter::EncodableMap details;
        if (std::string(event) != "leave") {
          ::ScreenToClient(file_drop_window_, &position);
          const UINT dpi = ::GetDpiForWindow(file_drop_window_);
          const double scale = dpi == 0 ? 1.0 : static_cast<double>(dpi) / 96.0;
          details[flutter::EncodableValue("x")] =
              flutter::EncodableValue(position.x / scale);
          details[flutter::EncodableValue("y")] =
              flutter::EncodableValue(position.y / scale);
        }
        flutter::EncodableList files;
        for (const auto& path : paths) files.emplace_back(path);
        details[flutter::EncodableValue("files")] = flutter::EncodableValue(files);
        file_drop_channel_->InvokeMethod(event,
            std::make_unique<flutter::EncodableValue>(details));
      });
  file_drop_available_ = SUCCEEDED(
      ::RegisterDragDrop(file_drop_window_, file_drop_target_));

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
  if (file_drop_available_) ::RevokeDragDrop(file_drop_window_);
  if (file_drop_target_) {
    file_drop_target_->Release();
    file_drop_target_ = nullptr;
  }
  file_drop_available_ = false;
  if (flutter_controller_) {
    file_dialog_channel_.reset();
    window_theme_channel_.reset();
    activation_channel_.reset();
    spell_check_channel_.reset();
    file_drop_channel_.reset();
    widget_preview_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_COPYDATA) {
    const auto* packet = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
    if (packet == nullptr || packet->dwData != 0x54444F52 ||
        packet->cbData == 0 || packet->cbData > 4096 ||
        packet->lpData == nullptr) return FALSE;
    const auto* bytes = static_cast<const char*>(packet->lpData);
    pending_activation_.assign(bytes, bytes + packet->cbData);
    if (::IsIconic(hwnd)) ::ShowWindow(hwnd, SW_RESTORE);
    else ::ShowWindow(hwnd, SW_SHOW);
    ::SetForegroundWindow(hwnd);
    DeliverActivation();
    return TRUE;
  }
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
