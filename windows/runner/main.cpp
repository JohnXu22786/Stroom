#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"stroom", origin, size)) {
    return EXIT_FAILURE;
  }
  // 关闭窗口的默认行为由 Dart 侧的 window_manager 插件接管：
  // 应用初始化完成后会调用 setPreventClose(true)，此时 WM_CLOSE 被插件
  // 拦截，窗口隐藏到系统托盘继续后台运行（见 lib/services/
  // desktop_app_service.dart）。这里的 SetQuitOnClose(true) 仅作为
  // 插件初始化完成前的安全兜底：此时点击关闭会干净地退出进程，
  // 避免出现「窗口已销毁但进程仍在后台空转」的幽灵进程。
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
