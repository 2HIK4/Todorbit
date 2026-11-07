#include "../windows/runner/private_credential_store.h"
#include <filesystem>
#include <fstream>
#include <iostream>

using todorbit_private::CredentialStore;
namespace fs = std::filesystem;
void Check(bool value) { if (!value) throw std::runtime_error("isolation assertion failed"); }
std::string Key(char value) { return "todorbit.drive." + std::string(64, value) + ".tokens"; }
void Put(const fs::path& file, const std::string& value) {
  std::ofstream output(file, std::ios::binary | std::ios::trunc); output << value;
  if (!output) throw std::runtime_error("fixture write failed");
}
int wmain(int argc, wchar_t** argv) {
  const char* stage = "setup";
  try {
    if (argc < 3) return 2;
    const fs::path root(argv[2]);
    const auto directory = root / L"Profile" / L"private-credentials";
    if (std::wstring(argv[1]) == L"child") {
      if (argc != 4) return 2;
      CredentialStore store(root.wstring(), directory.wstring(), Key(static_cast<char>(argv[3][0])));
      for (int i = 0; i < 3; ++i) {
        store.Write("synthetic-child-" + std::to_string(i));
        const auto read = store.Read();
        Check(read && read->rfind("synthetic-child-", 0) == 0);
      }
      return 0;
    }
    Check(!fs::exists(root)); fs::create_directories(root);
    Put(root / L"TODORBIT-PRIVATE-DRIVE-TEST", "todorbit-private-drive-test-v1");
    // Synthetic production sentinel: never a personal credential or profile.
    const auto production = root.parent_path() / (root.filename().wstring() + L"-production.dpapi");
    Put(production, "synthetic-production-ciphertext");
    const auto before = todorbit_private::ReadBytes(production.wstring());
    CredentialStore a(root.wstring(), directory.wstring(), Key('a'));
    CredentialStore b(root.wstring(), directory.wstring(), Key('b'));
    Check(!a.Read());
    a.Write("synthetic-alpha"); b.Write("synthetic-beta");
    Check(a.Read() == "synthetic-alpha" && b.Read() == "synthetic-beta");
    const auto b_file = directory / (std::string(64, 'b') + ".tokens.dpapi");
    const auto a_file = directory / (std::string(64, 'a') + ".tokens.dpapi");
    const auto b_cipher = todorbit_private::ReadBytes(b_file.wstring());
    const auto a_cipher = todorbit_private::ReadBytes(a_file.wstring());
    Put(b_file, std::string(a_cipher.begin(), a_cipher.end()));
    bool wrong_scope = false; try { b.Read(); } catch (...) { wrong_scope = true; }
    Check(wrong_scope);
    Put(b_file, std::string(b_cipher.begin(), b_cipher.end()));
    stage = "atomic write failure";
    const auto target = directory / (std::string(64, 'a') + ".tokens.dpapi");
    const auto encrypted = todorbit_private::ReadBytes(target.wstring());
    Check(std::search(encrypted.begin(), encrypted.end(), "synthetic-alpha", "synthetic-alpha" + 15) == encrypted.end());
    // Real OS sharing denial forces commit failure after encrypted temp flush.
    {
      todorbit_private::Handle held(CreateFileW(target.c_str(), GENERIC_READ,
          FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
      bool failed = false; try { a.Write("synthetic-replacement"); } catch (...) { failed = true; }
      Check(failed);
    }
    Check(todorbit_private::ReadBytes(target.wstring()) == encrypted);
    for (const auto& entry : fs::directory_iterator(directory)) Check(entry.path().wstring().find(L".tmp-") == std::wstring::npos);
    Put(target, "synthetic-corrupt");
    bool failed = false; try { a.Read(); } catch (...) { failed = true; }
    Check(failed && todorbit_private::ReadBytes(target.wstring()).size() == 17);
    a.Delete(); Check(!a.Read() && b.Read() == "synthetic-beta");
    failed = false; try { CredentialStore invalid(root.wstring(), root.parent_path().wstring(), Key('a')); } catch (...) { failed = true; }
    Check(failed);
    failed = false; try { CredentialStore invalid(root.wstring(), directory.wstring(), "../../production"); } catch (...) { failed = true; }
    Check(failed);
    stage = "concurrent child processes";
    wchar_t executable[32768]; Check(GetModuleFileNameW(nullptr, executable, 32768) != 0);
    std::vector<HANDLE> children;
    std::vector<fs::path> child_logs;
    for (wchar_t key : {L'c', L'c', L'd', L'e'}) {
      std::wstring command = L"\"" + std::wstring(executable) + L"\" child \"" + root.wstring() + L"\" " + key;
      SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
      const auto log = root / (L"child-" + std::to_wstring(children.size()) + L".log");
      todorbit_private::Handle output(CreateFileW(log.c_str(), GENERIC_WRITE, FILE_SHARE_READ,
          &security, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr));
      todorbit_private::Handle input(CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
          &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
      STARTUPINFOW startup{}; startup.cb = sizeof(startup); startup.dwFlags = STARTF_USESTDHANDLES;
      startup.hStdOutput = output.get(); startup.hStdError = output.get(); startup.hStdInput = input.get();
      PROCESS_INFORMATION process{};
      Check(CreateProcessW(nullptr, command.data(), nullptr, nullptr, TRUE, CREATE_NO_WINDOW,
                            nullptr, nullptr, &startup, &process));
      CloseHandle(process.hThread); children.push_back(process.hProcess); child_logs.push_back(log);
    }
    if (WaitForMultipleObjects(static_cast<DWORD>(children.size()), children.data(), TRUE, 120000) != WAIT_OBJECT_0) {
      for (const auto child : children) { TerminateProcess(child, 3); CloseHandle(child); }
      throw std::runtime_error("Concurrent fixture timed out; owned children terminated.");
    }
    bool child_failed = false;
    for (size_t i = 0; i < children.size(); ++i) {
      DWORD code = 1; Check(GetExitCodeProcess(children[i], &code)); CloseHandle(children[i]);
      if (code != 0) { std::ifstream log(child_logs[i]); std::cerr << log.rdbuf(); child_failed = true; }
    }
    Check(!child_failed);
    stage = "post-process cleanup";
    for (char key : {'c', 'd', 'e'}) {
      CredentialStore store(root.wstring(), directory.wstring(), Key(key));
      Check(store.Read().has_value()); store.Delete(); Check(!store.Read());
    }
    Check(todorbit_private::ReadBytes(production.wstring()) == before);
    Check(b.Read() == "synthetic-beta");
    std::cout << "PASS: DPAPI, independent keys, failed commit preservation, scoped corruption/disconnect, path rejection, four concurrent processes, production sentinel unchanged\n";
    return 0;
  } catch (const std::exception& error) { std::cerr << "FAIL stage " << stage << ": " << error.what() << " (synthetic fixtures only)\n"; return 1; }
}
