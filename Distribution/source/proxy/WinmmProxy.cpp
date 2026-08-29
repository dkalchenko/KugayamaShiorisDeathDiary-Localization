#include <windows.h>
#include <bcrypt.h>
#define _WINMM_
#include <mmsystem.h>

#include <array>
#include <cstring>
#include <string>

#pragma comment(lib, "bcrypt.lib")

namespace
{
constexpr wchar_t GameExecutableName[] = L"KugayamaShiorisDeathDiary.exe";
constexpr wchar_t GameExecutableSha256[] = L"2224D4B10114AAEA3CD8C7C144DAE9C6AB3AFF224DB1E137DD4AFA0BA5491696";
constexpr wchar_t PatchArchiveSha256[] = L"FC489EDDE26256C5505B9E8D9777DDB070330BFABF16E47D3184CDF11C128035";
constexpr wchar_t DeferEnvironmentVariable[] = L"KRKRPATCH_DEFER_STARTUP";

using TimeBeginPeriodProc = MMRESULT(WINAPI*)(UINT);
using TimeEndPeriodProc = MMRESULT(WINAPI*)(UINT);
using TimeGetDevCapsProc = MMRESULT(WINAPI*)(LPTIMECAPS, UINT);
using TimeGetTimeProc = DWORD(WINAPI*)();
using WaveOutOpenProc = decltype(&::waveOutOpen);
using WaveOutCloseProc = decltype(&::waveOutClose);
using WaveOutMessageProc = decltype(&::waveOutMessage);
using WaveOutGetDevCapsWProc = decltype(&::waveOutGetDevCapsW);
using WaveInOpenProc = decltype(&::waveInOpen);
using WaveInCloseProc = decltype(&::waveInClose);
using WaveInMessageProc = decltype(&::waveInMessage);
using MixerGetDevCapsAProc = decltype(&::mixerGetDevCapsA);
using MixerOpenProc = decltype(&::mixerOpen);
using MixerCloseProc = decltype(&::mixerClose);
using MixerGetLineInfoAProc = decltype(&::mixerGetLineInfoA);
using MixerGetIDProc = decltype(&::mixerGetID);
using MixerGetLineControlsAProc = decltype(&::mixerGetLineControlsA);
using MixerGetControlDetailsAProc = decltype(&::mixerGetControlDetailsA);
using MixerSetControlDetailsProc = decltype(&::mixerSetControlDetails);
using InitializeKrkrPatchProc = BOOL(*)();

INIT_ONCE g_winmmOnce = INIT_ONCE_STATIC_INIT;
INIT_ONCE g_localizationOnce = INIT_ONCE_STATIC_INIT;
HMODULE g_realWinmm = nullptr;
TimeBeginPeriodProc g_timeBeginPeriod = nullptr;
TimeEndPeriodProc g_timeEndPeriod = nullptr;
TimeGetDevCapsProc g_timeGetDevCaps = nullptr;
TimeGetTimeProc g_timeGetTime = nullptr;
WaveOutOpenProc g_waveOutOpen = nullptr;
WaveOutCloseProc g_waveOutClose = nullptr;
WaveOutMessageProc g_waveOutMessage = nullptr;
WaveOutGetDevCapsWProc g_waveOutGetDevCapsW = nullptr;
WaveInOpenProc g_waveInOpen = nullptr;
WaveInCloseProc g_waveInClose = nullptr;
WaveInMessageProc g_waveInMessage = nullptr;
MixerGetDevCapsAProc g_mixerGetDevCapsA = nullptr;
MixerOpenProc g_mixerOpen = nullptr;
MixerCloseProc g_mixerClose = nullptr;
MixerGetLineInfoAProc g_mixerGetLineInfoA = nullptr;
MixerGetIDProc g_mixerGetID = nullptr;
MixerGetLineControlsAProc g_mixerGetLineControlsA = nullptr;
MixerGetControlDetailsAProc g_mixerGetControlDetailsA = nullptr;
MixerSetControlDetailsProc g_mixerSetControlDetails = nullptr;
thread_local bool g_initializingLocalization = false;

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

BOOL CALLBACK LoadRealWinmm(PINIT_ONCE, PVOID, PVOID*)
{
    std::array<wchar_t, MAX_PATH> systemDirectory{};
    const auto length = GetSystemDirectoryW(systemDirectory.data(), static_cast<UINT>(systemDirectory.size()));
    if (length == 0 || length >= systemDirectory.size())
        return TRUE;

    const auto path = JoinPath(std::wstring(systemDirectory.data(), length), L"winmm.dll");
    g_realWinmm = LoadLibraryW(path.c_str());
    if (!g_realWinmm)
        return TRUE;

    g_timeBeginPeriod = reinterpret_cast<TimeBeginPeriodProc>(GetProcAddress(g_realWinmm, "timeBeginPeriod"));
    g_timeEndPeriod = reinterpret_cast<TimeEndPeriodProc>(GetProcAddress(g_realWinmm, "timeEndPeriod"));
    g_timeGetDevCaps = reinterpret_cast<TimeGetDevCapsProc>(GetProcAddress(g_realWinmm, "timeGetDevCaps"));
    g_timeGetTime = reinterpret_cast<TimeGetTimeProc>(GetProcAddress(g_realWinmm, "timeGetTime"));
    g_waveOutOpen = reinterpret_cast<WaveOutOpenProc>(GetProcAddress(g_realWinmm, "waveOutOpen"));
    g_waveOutClose = reinterpret_cast<WaveOutCloseProc>(GetProcAddress(g_realWinmm, "waveOutClose"));
    g_waveOutMessage = reinterpret_cast<WaveOutMessageProc>(GetProcAddress(g_realWinmm, "waveOutMessage"));
    g_waveOutGetDevCapsW = reinterpret_cast<WaveOutGetDevCapsWProc>(GetProcAddress(g_realWinmm, "waveOutGetDevCapsW"));
    g_waveInOpen = reinterpret_cast<WaveInOpenProc>(GetProcAddress(g_realWinmm, "waveInOpen"));
    g_waveInClose = reinterpret_cast<WaveInCloseProc>(GetProcAddress(g_realWinmm, "waveInClose"));
    g_waveInMessage = reinterpret_cast<WaveInMessageProc>(GetProcAddress(g_realWinmm, "waveInMessage"));
    g_mixerGetDevCapsA = reinterpret_cast<MixerGetDevCapsAProc>(GetProcAddress(g_realWinmm, "mixerGetDevCapsA"));
    g_mixerOpen = reinterpret_cast<MixerOpenProc>(GetProcAddress(g_realWinmm, "mixerOpen"));
    g_mixerClose = reinterpret_cast<MixerCloseProc>(GetProcAddress(g_realWinmm, "mixerClose"));
    g_mixerGetLineInfoA = reinterpret_cast<MixerGetLineInfoAProc>(GetProcAddress(g_realWinmm, "mixerGetLineInfoA"));
    g_mixerGetID = reinterpret_cast<MixerGetIDProc>(GetProcAddress(g_realWinmm, "mixerGetID"));
    g_mixerGetLineControlsA = reinterpret_cast<MixerGetLineControlsAProc>(GetProcAddress(g_realWinmm, "mixerGetLineControlsA"));
    g_mixerGetControlDetailsA = reinterpret_cast<MixerGetControlDetailsAProc>(GetProcAddress(g_realWinmm, "mixerGetControlDetailsA"));
    g_mixerSetControlDetails = reinterpret_cast<MixerSetControlDetailsProc>(GetProcAddress(g_realWinmm, "mixerSetControlDetails"));
    return TRUE;
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
        Log(directory, "Localization skipped: unsupported executable name.");
        return TRUE;
    }

    std::wstring actualHash;
    if (!Sha256(executablePath, actualHash) || _wcsicmp(actualHash.c_str(), GameExecutableSha256) != 0)
    {
        Log(directory, "Localization skipped: unsupported game executable hash; starting vanilla.");
        return TRUE;
    }

    const auto patchPath = JoinPath(directory, L"patch.xp3");
    if (!Sha256(patchPath, actualHash) || _wcsicmp(actualHash.c_str(), PatchArchiveSha256) != 0)
    {
        Log(directory, "Localization skipped: unsupported patch.xp3 hash; starting vanilla.");
        return TRUE;
    }

    for (const auto fileName : { L"KrkrPatch.dll", L"KrkrPatch.json", L"localization.xp3" })
    {
        if (GetFileAttributesW(JoinPath(directory, fileName).c_str()) == INVALID_FILE_ATTRIBUTES)
        {
            Log(directory, "Localization skipped: a required localization file is missing; starting vanilla.");
            return TRUE;
        }
    }

    std::array<wchar_t, 32768> previousValue{};
    const auto previousLength = GetEnvironmentVariableW(DeferEnvironmentVariable, previousValue.data(), static_cast<DWORD>(previousValue.size()));
    if (previousLength >= previousValue.size() || !SetEnvironmentVariableW(DeferEnvironmentVariable, L"1"))
    {
        Log(directory, "Localization skipped: deferred initialization could not be configured; starting vanilla.");
        return TRUE;
    }
    g_initializingLocalization = true;
    const auto module = LoadLibraryExW(JoinPath(directory, L"KrkrPatch.dll").c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    g_initializingLocalization = false;
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
        Log(directory, "Localization skipped: KrkrPatch initialization failed; starting vanilla.");
        return TRUE;
    }

    return TRUE;
}

__declspec(noinline) BOOL InitializeLocalizationWithCppGuard()
{
    try
    {
        return InitializeLocalizationCore();
    }
    catch (...)
    {
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
        return TRUE;
    }
}

void EnsureInitialized()
{
    InitOnceExecuteOnce(&g_winmmOnce, LoadRealWinmm, nullptr, nullptr);
    if (!g_initializingLocalization)
        InitOnceExecuteOnce(&g_localizationOnce, InitializeLocalization, nullptr, nullptr);
}
}

extern "C" MMRESULT WINAPI timeBeginPeriod(UINT period)
{
    EnsureInitialized();
    return g_timeBeginPeriod ? g_timeBeginPeriod(period) : TIMERR_NOCANDO;
}

extern "C" MMRESULT WINAPI timeEndPeriod(UINT period)
{
    EnsureInitialized();
    return g_timeEndPeriod ? g_timeEndPeriod(period) : TIMERR_NOCANDO;
}

extern "C" MMRESULT WINAPI timeGetDevCaps(LPTIMECAPS capabilities, UINT size)
{
    EnsureInitialized();
    return g_timeGetDevCaps ? g_timeGetDevCaps(capabilities, size) : TIMERR_NOCANDO;
}

extern "C" DWORD WINAPI timeGetTime()
{
    EnsureInitialized();
    return g_timeGetTime ? g_timeGetTime() : GetTickCount();
}

extern "C" MMRESULT WINAPI waveOutOpen(LPHWAVEOUT output, UINT_PTR deviceId, LPCWAVEFORMATEX format,
    DWORD_PTR callback, DWORD_PTR instance, DWORD flags)
{
    EnsureInitialized();
    return g_waveOutOpen ? g_waveOutOpen(output, deviceId, format, callback, instance, flags) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI waveOutClose(HWAVEOUT output)
{
    EnsureInitialized();
    return g_waveOutClose ? g_waveOutClose(output) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI waveOutMessage(HWAVEOUT output, UINT message, DWORD_PTR parameter1, DWORD_PTR parameter2)
{
    EnsureInitialized();
    return g_waveOutMessage ? g_waveOutMessage(output, message, parameter1, parameter2) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI waveOutGetDevCapsW(UINT_PTR deviceId, LPWAVEOUTCAPSW capabilities, UINT size)
{
    EnsureInitialized();
    return g_waveOutGetDevCapsW ? g_waveOutGetDevCapsW(deviceId, capabilities, size) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI waveInOpen(LPHWAVEIN input, UINT_PTR deviceId, LPCWAVEFORMATEX format,
    DWORD_PTR callback, DWORD_PTR instance, DWORD flags)
{
    EnsureInitialized();
    return g_waveInOpen ? g_waveInOpen(input, deviceId, format, callback, instance, flags) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI waveInClose(HWAVEIN input)
{
    EnsureInitialized();
    return g_waveInClose ? g_waveInClose(input) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI waveInMessage(HWAVEIN input, UINT message, DWORD_PTR parameter1, DWORD_PTR parameter2)
{
    EnsureInitialized();
    return g_waveInMessage ? g_waveInMessage(input, message, parameter1, parameter2) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI mixerGetDevCapsA(UINT_PTR mixerId, LPMIXERCAPSA capabilities, UINT size)
{
    EnsureInitialized();
    return g_mixerGetDevCapsA ? g_mixerGetDevCapsA(mixerId, capabilities, size) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI mixerOpen(LPHMIXER mixer, UINT mixerId, DWORD_PTR callback, DWORD_PTR instance, DWORD flags)
{
    EnsureInitialized();
    return g_mixerOpen ? g_mixerOpen(mixer, mixerId, callback, instance, flags) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI mixerClose(HMIXER mixer)
{
    EnsureInitialized();
    return g_mixerClose ? g_mixerClose(mixer) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI mixerGetLineInfoA(HMIXEROBJ mixer, LPMIXERLINEA line, DWORD flags)
{
    EnsureInitialized();
    return g_mixerGetLineInfoA ? g_mixerGetLineInfoA(mixer, line, flags) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI mixerGetID(HMIXEROBJ mixer, UINT* mixerId, DWORD flags)
{
    EnsureInitialized();
    return g_mixerGetID ? g_mixerGetID(mixer, mixerId, flags) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI mixerGetLineControlsA(HMIXEROBJ mixer, LPMIXERLINECONTROLSA controls, DWORD flags)
{
    EnsureInitialized();
    return g_mixerGetLineControlsA ? g_mixerGetLineControlsA(mixer, controls, flags) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI mixerGetControlDetailsA(HMIXEROBJ mixer, LPMIXERCONTROLDETAILS details, DWORD flags)
{
    EnsureInitialized();
    return g_mixerGetControlDetailsA ? g_mixerGetControlDetailsA(mixer, details, flags) : MMSYSERR_NODRIVER;
}

extern "C" MMRESULT WINAPI mixerSetControlDetails(HMIXEROBJ mixer, LPMIXERCONTROLDETAILS details, DWORD flags)
{
    EnsureInitialized();
    return g_mixerSetControlDetails ? g_mixerSetControlDetails(mixer, details, flags) : MMSYSERR_NODRIVER;
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
        DisableThreadLibraryCalls(module);
    return TRUE;
}
