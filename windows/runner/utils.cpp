#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }

  // Windows command lines are limited to 32767 UTF-16 characters, including
  // the terminating null. Bound the scan and allocation to that limit.
  constexpr size_t kMaxCommandLineLength = 32767;
  size_t input_length = 0;
  while (input_length < kMaxCommandLineLength &&
         utf16_string[input_length] != L'\0') {
    ++input_length;
  }
  if (input_length == kMaxCommandLineLength) {
    return std::string();
  }

  if (input_length == 0) {
    return std::string();
  }

  const int input_length_int = static_cast<int>(input_length);
  const int required_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string, input_length_int, nullptr, 0,
      nullptr, nullptr);
  if (required_length == 0) {
    return std::string();
  }

  std::string utf8_string;
  if (static_cast<size_t>(required_length) > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(static_cast<size_t>(required_length));
  const int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string, input_length_int,
      utf8_string.data(), required_length, nullptr, nullptr);
  if (converted_length != required_length) {
    return std::string();
  }
  return utf8_string;
}
