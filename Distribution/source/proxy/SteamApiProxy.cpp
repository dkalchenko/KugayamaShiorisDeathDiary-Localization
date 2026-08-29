#include <windows.h>
#include <bcrypt.h>

#include <array>
#include <cstring>
#include <string>

#pragma comment(lib, "bcrypt.lib")

namespace
{
constexpr wchar_t GameExecutableName[] = L"KugayamaShiorisDeathDiary.exe";
constexpr wchar_t GameExecutableSha256[] = L"2224D4B10114AAEA3CD8C7C144DAE9C6AB3AFF224DB1E137DD4AFA0BA5491696";
constexpr wchar_t PatchArchiveSha256[] = L"FC489EDDE26256C5505B9E8D9777DDB070330BFABF16E47D3184CDF11C128035";
constexpr wchar_t OriginalSteamApiSha256[] = L"DF431862608823F54DF423428296273E1CA65C9928FA93633B882FE1C3D7D153";
constexpr wchar_t DeferEnvironmentVariable[] = L"KRKRPATCH_DEFER_STARTUP";

using InitializeKrkrPatchProc = BOOL(*)();

INIT_ONCE g_localizationOnce = INIT_ONCE_STATIC_INIT;

std::wstring GetDirectory(const std::wstring& path)
{
    const auto separator = path.find_last_of(L"\\/");
    return separator == std::wstring::npos ? std::wstring() : path.substr(0, separator);
}

std::wstring GetFileName(const std::wstring& path)
{
    const auto separator = path.find_last_of(L"\\/");
    return separator == std::wstring::npos ? path : path.substr(separator + 1);
}

std::wstring JoinPath(const std::wstring& directory, const wchar_t* name)
{
    return directory + L"\\" + name;
}

void Log(const std::wstring& directory, const char* message)
{
    const auto path = JoinPath(directory, L"LocalizationBootstrap.log");
    const auto file = CreateFileW(path.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE)
        return;

    DWORD written = 0;
    WriteFile(file, message, static_cast<DWORD>(strlen(message)), &written, nullptr);
    WriteFile(file, "\r\n", 2, &written, nullptr);
    CloseHandle(file);
}

bool GetExecutablePath(std::wstring& path)
{
    std::array<wchar_t, 32768> buffer{};
    const auto length = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (length == 0 || length >= buffer.size())
        return false;
    path.assign(buffer.data(), length);
    return true;
}

bool IsFile(const std::wstring& path)
{
    const auto attributes = GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

bool Sha256(const std::wstring& path, std::wstring& result)
{
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;
    HANDLE file = INVALID_HANDLE_VALUE;
    DWORD objectLength = 0;
    DWORD valueLength = 0;
    std::array<UCHAR, 32> digest{};
    std::array<UCHAR, 65536> buffer{};
    constexpr wchar_t hex[] = L"0123456789ABCDEF";
    PUCHAR object = nullptr;
    bool success = false;

    if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0)
        goto cleanup;
    if (BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, reinterpret_cast<PUCHAR>(&objectLength), sizeof(objectLength), &valueLength, 0) < 0)
        goto cleanup;
    object = static_cast<PUCHAR>(HeapAlloc(GetProcessHeap(), 0, objectLength));
    if (!object)
        goto cleanup;
    if (BCryptCreateHash(algorithm, &hash, object, objectLength, nullptr, 0, 0) < 0)
        goto cleanup;

    file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        nullptr, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
    if (file == INVALID_HANDLE_VALUE)
        goto cleanup;

    for (;;)
    {
        DWORD bytesRead = 0;
        if (!ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &bytesRead, nullptr))
            goto cleanup;
        if (bytesRead == 0)
            break;
        if (BCryptHashData(hash, buffer.data(), bytesRead, 0) < 0)
            goto cleanup;
    }
    if (BCryptFinishHash(hash, digest.data(), static_cast<ULONG>(digest.size()), 0) < 0)
        goto cleanup;

    result.clear();
    result.reserve(digest.size() * 2);
    for (const auto byte : digest)
    {
        result.push_back(hex[byte >> 4]);
        result.push_back(hex[byte & 0x0f]);
    }
    success = true;

cleanup:
    if (file != INVALID_HANDLE_VALUE)
        CloseHandle(file);
    if (hash)
        BCryptDestroyHash(hash);
    if (object)
        HeapFree(GetProcessHeap(), 0, object);
    if (algorithm)
        BCryptCloseAlgorithmProvider(algorithm, 0);
    return success;
}

BOOL CallInitializeKrkrPatch(InitializeKrkrPatchProc initialize)
{
    __try
    {
        return initialize();
    }
    __except (EXCEPTION_EXECUTE_HANDLER)
    {
        return FALSE;
    }
}

BOOL InitializeLocalizationCore()
{
    std::wstring executablePath;
    if (!GetExecutablePath(executablePath))
        return TRUE;

    const auto directory = GetDirectory(executablePath);
    if (_wcsicmp(GetFileName(executablePath).c_str(), GameExecutableName) != 0)
    {
        Log(directory, "Localization skipped: unsupported executable name; starting vanilla.");
        return TRUE;
    }

    for (const auto fileName : { L"KrkrPatch.dll", L"KrkrPatch.json", L"localization.xp3", L"patch.xp3", L"steam_api_original.dll" })
    {
        if (!IsFile(JoinPath(directory, fileName)))
        {
            Log(directory, "Localization skipped: a required file is missing; starting vanilla.");
            return TRUE;
        }
    }

    std::wstring actualHash;
    if (!Sha256(executablePath, actualHash) || _wcsicmp(actualHash.c_str(), GameExecutableSha256) != 0)
    {
        Log(directory, "Localization skipped: unsupported game executable; starting vanilla.");
        return TRUE;
    }

    if (!Sha256(JoinPath(directory, L"patch.xp3"), actualHash) || _wcsicmp(actualHash.c_str(), PatchArchiveSha256) != 0)
    {
        Log(directory, "Localization skipped: unsupported patch.xp3; starting vanilla.");
        return TRUE;
    }

    if (!Sha256(JoinPath(directory, L"steam_api_original.dll"), actualHash) || _wcsicmp(actualHash.c_str(), OriginalSteamApiSha256) != 0)
    {
        Log(directory, "Localization skipped: unsupported original Steam file; starting vanilla.");
        return TRUE;
    }

    std::array<wchar_t, 32768> previousValue{};
    const auto previousLength = GetEnvironmentVariableW(DeferEnvironmentVariable, previousValue.data(), static_cast<DWORD>(previousValue.size()));
    if (previousLength >= previousValue.size() || !SetEnvironmentVariableW(DeferEnvironmentVariable, L"1"))
    {
        Log(directory, "Localization skipped: startup could not be prepared; starting vanilla.");
        return TRUE;
    }

    const auto module = LoadLibraryExW(JoinPath(directory, L"KrkrPatch.dll").c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (previousLength > 0 && previousLength < previousValue.size())
        SetEnvironmentVariableW(DeferEnvironmentVariable, previousValue.data());
    else
        SetEnvironmentVariableW(DeferEnvironmentVariable, nullptr);

    if (!module)
    {
        Log(directory, "Localization skipped: KrkrPatch.dll could not be loaded; starting vanilla.");
        return TRUE;
    }

    auto initialize = reinterpret_cast<InitializeKrkrPatchProc>(GetProcAddress(module, "InitializeKrkrPatch"));
    if (!initialize)
        initialize = reinterpret_cast<InitializeKrkrPatchProc>(GetProcAddress(module, "_InitializeKrkrPatch"));
    if (!initialize || !CallInitializeKrkrPatch(initialize))
    {
        Log(directory, "Localization skipped: localization startup failed; starting vanilla.");
        return TRUE;
    }

    Log(directory, "Localization initialized.");
    return TRUE;
}

void LogForExecutable(const char* message) noexcept
{
    try
    {
        std::wstring executablePath;
        if (GetExecutablePath(executablePath))
            Log(GetDirectory(executablePath), message);
    }
    catch (...)
    {
    }
}

__declspec(noinline) BOOL InitializeLocalizationWithCppGuard()
{
    try
    {
        return InitializeLocalizationCore();
    }
    catch (...)
    {
        LogForExecutable("Localization skipped: unexpected startup error; starting vanilla.");
        return TRUE;
    }
}

BOOL CALLBACK InitializeLocalization(PINIT_ONCE, PVOID, PVOID*)
{
    __try
    {
        return InitializeLocalizationWithCppGuard();
    }
    __except (EXCEPTION_EXECUTE_HANDLER)
    {
        LogForExecutable("Localization skipped: unexpected startup failure; starting vanilla.");
        return TRUE;
    }
}

DWORD WINAPI LocalizationWorker(LPVOID)
{
    InitOnceExecuteOnce(&g_localizationOnce, InitializeLocalization, nullptr, nullptr);
    return 0;
}

void StartLocalizationWorker()
{
    const auto thread = CreateThread(nullptr, 0, LocalizationWorker, nullptr, 0, nullptr);
    if (thread)
        CloseHandle(thread);
}
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        DisableThreadLibraryCalls(module);
        StartLocalizationWorker();
    }
    return TRUE;
}
