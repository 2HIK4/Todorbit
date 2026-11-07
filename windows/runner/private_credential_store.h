#ifndef TODORBIT_PRIVATE_CREDENTIAL_STORE_H_
#define TODORBIT_PRIVATE_CREDENTIAL_STORE_H_

#include <windows.h>
#include <wincrypt.h>
#include <algorithm>
#include <atomic>
#include <cwctype>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

// Only the explicitly marked acceptance root. No Known Folders, registry,
// Credential Manager, migration, or production-store fallback is used here.
namespace todorbit_private {
inline std::wstring LongPath(const std::wstring& value) { return L"\\\\?\\" + value; }
inline std::wstring Canonical(const std::wstring& value) {
  if (value.size() < 3 || value[1] != L':' || value[2] != L'\\')
    throw std::runtime_error("Private credential path must be local and absolute.");
  const DWORD size = GetFullPathNameW(value.c_str(), 0, nullptr, nullptr);
  if (!size) throw std::runtime_error("Private credential path is invalid.");
  std::wstring result(size, 0);
  if (!GetFullPathNameW(value.c_str(), size, result.data(), nullptr))
    throw std::runtime_error("Private credential path is invalid.");
  result.resize(size - 1);
  while (result.size() > 3 && result.back() == L'\\') result.pop_back();
  std::transform(result.begin(), result.end(), result.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return result;
}
class Handle {
 public:
  explicit Handle(HANDLE value) : value_(value) {
    if (value_ == INVALID_HANDLE_VALUE) throw std::runtime_error("Private credential file unavailable.");
  }
  ~Handle() { CloseHandle(value_); }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
  HANDLE get() const { return value_; }
 private:
  HANDLE value_;
};
inline void NoLink(const std::wstring& path) {
  const DWORD attributes = GetFileAttributesW(LongPath(path).c_str());
  if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT))
    throw std::runtime_error("Private credentials cannot use linked paths.");
}
inline std::vector<BYTE> ReadBytes(const std::wstring& path) {
  NoLink(path);
  Handle file(CreateFileW(LongPath(path).c_str(), GENERIC_READ, FILE_SHARE_READ,
      nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
  LARGE_INTEGER size{};
  if (!GetFileSizeEx(file.get(), &size) || size.QuadPart < 0 || size.QuadPart > 131072)
    throw std::runtime_error("Private credential file is invalid; retained unchanged.");
  std::vector<BYTE> bytes(static_cast<size_t>(size.QuadPart));
  DWORD read = 0;
  if (!ReadFile(file.get(), bytes.data(), static_cast<DWORD>(bytes.size()), &read, nullptr) || read != bytes.size())
    throw std::runtime_error("Private credential file could not be read.");
  return bytes;
}
class Lock {
 public:
  explicit Lock(const std::wstring& path) : file_(Open(path)) {
    const ULONGLONG deadline = GetTickCount64() + 5000;
    while (!LockFileEx(file_.get(), LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY,
                       0, 1, 0, &overlap_)) {
      if (GetLastError() != ERROR_LOCK_VIOLATION || GetTickCount64() >= deadline)
        throw std::runtime_error("Private credentials are busy; retry later.");
      Sleep(10);
    }
  }
  ~Lock() { UnlockFileEx(file_.get(), 0, 1, 0, &overlap_); }
 private:
  static HANDLE Open(const std::wstring& path) {
    NoLink(path);
    return CreateFileW(LongPath(path).c_str(), GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  }
  Handle file_;
  OVERLAPPED overlap_{};
};
class CredentialStore {
 public:
  CredentialStore(const std::wstring& root, const std::wstring& directory,
                  const std::string& key) : directory_(Canonical(directory)) {
    const auto canonical_root = Canonical(root);
    if (directory_ != canonical_root + L"\\profile\\private-credentials")
      throw std::runtime_error("Private credential directory is outside its profile.");
    // Reject linked ancestors too, including a redirected test root.
    for (size_t i = 3; i <= canonical_root.size(); ++i) {
      if (i == canonical_root.size() || canonical_root[i] == L'\\') NoLink(canonical_root.substr(0, i));
    }
    const auto marker = ReadBytes(canonical_root + L"\\TODORBIT-PRIVATE-DRIVE-TEST");
    std::string text(marker.begin(), marker.end());
    while (!text.empty() && (text.back() == '\r' || text.back() == '\n')) text.pop_back();
    if (text != "todorbit-private-drive-test-v1") throw std::runtime_error("Private test marker invalid.");
    const std::string prefix = "todorbit.drive.";
    if (key.rfind(prefix, 0) != 0 || key.size() < prefix.size() + 66)
      throw std::runtime_error("Private credential key invalid.");
    const auto digest = key.substr(prefix.size(), 64);
    if (digest.find_first_not_of("0123456789abcdef") != std::string::npos)
      throw std::runtime_error("Private credential key invalid.");
    const auto purpose = key.substr(prefix.size() + 64);
    if (purpose != ".tokens" && purpose != ".sync-workspace-key" &&
        purpose != ".sync-reset-operation" && purpose != ".oauth-client")
      throw std::runtime_error("Private credential purpose invalid.");
    MakeDirectory(canonical_root + L"\\profile");
    MakeDirectory(directory_);
    const auto filename = digest + purpose + ".dpapi";
    path_ = directory_ + L"\\" + std::wstring(filename.begin(), filename.end());
    NoLink(path_);
  }
  std::optional<std::string> Read() const {
    Lock lock(path_ + L".lock");
    const auto attributes = GetFileAttributesW(LongPath(path_).c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES && GetLastError() == ERROR_FILE_NOT_FOUND) return std::nullopt;
    auto bytes = ReadBytes(path_);
    DATA_BLOB input{static_cast<DWORD>(bytes.size()), bytes.data()}, output{};
    DATA_BLOB entropy{static_cast<DWORD>(path_.size() * sizeof(wchar_t)), reinterpret_cast<BYTE*>(const_cast<wchar_t*>(path_.data()))};
    if (!CryptUnprotectData(&input, nullptr, &entropy, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output))
      throw std::runtime_error("Private credentials cannot be decrypted; retained unchanged.");
    std::string result(reinterpret_cast<char*>(output.pbData), output.cbData);
    SecureZeroMemory(output.pbData, output.cbData);
    LocalFree(output.pbData);
    return result;
  }
  void Write(const std::string& value) const {
    if (value.size() > 65536) throw std::runtime_error("Private credential exceeds size limit.");
    Lock lock(path_ + L".lock");
    NoLink(path_);
    DATA_BLOB input{static_cast<DWORD>(value.size()), reinterpret_cast<BYTE*>(const_cast<char*>(value.data()))}, output{};
    DATA_BLOB entropy{static_cast<DWORD>(path_.size() * sizeof(wchar_t)), reinterpret_cast<BYTE*>(const_cast<wchar_t*>(path_.data()))};
    if (!CryptProtectData(&input, L"Todorbit private acceptance", &entropy, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &output))
      throw std::runtime_error("Private credentials could not be protected.");
    std::vector<BYTE> encrypted(output.pbData, output.pbData + output.cbData);
    LocalFree(output.pbData);
    static std::atomic<unsigned long> sequence{0};
    const auto temporary = path_ + L".tmp-" + std::to_wstring(GetCurrentProcessId()) +
        L"-" + std::to_wstring(GetTickCount64()) + L"-" + std::to_wstring(++sequence);
    bool created = false;
    try {
      {
        Handle file(CreateFileW(LongPath(temporary).c_str(), GENERIC_WRITE, 0, nullptr,
            CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr));
        created = true;
        DWORD written = 0;
        if (!WriteFile(file.get(), encrypted.data(), static_cast<DWORD>(encrypted.size()), &written, nullptr) ||
            written != encrypted.size() || !FlushFileBuffers(file.get()))
          throw std::runtime_error("Private credential write failed; previous file retained.");
      }
      if (!MoveFileExW(LongPath(temporary).c_str(), LongPath(path_).c_str(),
                       MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        throw std::runtime_error("Private credential commit failed; previous file retained.");
    } catch (...) {
      if (created) DeleteFileW(LongPath(temporary).c_str());
      throw;
    }
  }
  void Delete() const {
    Lock lock(path_ + L".lock");
    NoLink(path_);
    if (!DeleteFileW(LongPath(path_).c_str()) && GetLastError() != ERROR_FILE_NOT_FOUND)
      throw std::runtime_error("Private credential could not be removed.");
  }
 private:
  static void MakeDirectory(const std::wstring& path) {
    NoLink(path);
    if (!CreateDirectoryW(LongPath(path).c_str(), nullptr) && GetLastError() != ERROR_ALREADY_EXISTS)
      throw std::runtime_error("Private credential directory unavailable.");
  }
  std::wstring directory_, path_;
};
}  // namespace todorbit_private
#endif
