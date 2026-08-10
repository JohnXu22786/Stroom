#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import asyncio
import codecs
import ctypes
import ctypes.wintypes
import hashlib
import os
import platform
import signal
import socket
import subprocess
import sys
import time

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.css.query import NoMatches
from textual.widgets import Button, TextArea

PORT_START = 7390
HOST = "localhost"
DEVICE = "chrome"
ROOT = os.path.dirname(os.path.abspath(__file__))

# Cap the on-screen output so long sessions don't eat unbounded memory.
# The trim rebuilds the TextArea, so only run it once per this many lines.
MAX_OUTPUT_LINES = 20000
TRIM_SLACK = 512


C_INFO = "\033[96m"
C_OK = "\033[92m"
C_WARN = "\033[93m"
C_ERR = "\033[91m"
C_PORT = "\033[95m"
C_END = "\033[0m"


def info(s):
    print(f"{C_INFO}[INFO]{C_END} {s}")


def ok(s):
    print(f"{C_OK}[OK]{C_END} {s}")


def warn(s):
    print(f"{C_WARN}[WARN]{C_END} {s}")


def err(s):
    print(f"{C_ERR}[ERROR]{C_END} {s}")


def pport(s):
    print(f"{C_PORT}[PORT]{C_END} {s}")


def run_flutter(args, cwd=None):
    """Run a flutter command, streaming output while still capturing it."""
    path = cwd or ROOT
    if platform.system() == "Windows":
        cmd = ["flutter.bat"] + args
    else:
        cmd = ["flutter"] + args
    proc = subprocess.Popen(
        cmd,
        cwd=path,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    stdout_lines = []
    for line in proc.stdout:
        print(line, end="", flush=True)
        stdout_lines.append(line)
    proc.wait()
    return subprocess.CompletedProcess(cmd, proc.returncode, "".join(stdout_lines), "")


def check_flutter():
    try:
        r = run_flutter(["--version"])
    except OSError as e:
        err(f"Failed to run flutter: {e}")
        return False
    if r.returncode != 0:
        err("Flutter not found")
        return False
    info("Flutter: " + (r.stdout.splitlines() or ["?"])[0])
    return True


def check_project():
    pub = os.path.join(ROOT, "pubspec.yaml")
    if not os.path.exists(pub):
        err("pubspec.yaml not found")
        err("Place script in Flutter project root")
        return False
    with open(pub, "r", encoding="utf-8") as f:
        if "flutter:" not in f.read():
            err("Invalid Flutter project")
            return False
    ok("Project: " + os.path.basename(ROOT))
    return True


def check_chrome():
    global DEVICE
    if platform.system() == "Windows":
        paths = [
            os.path.join(
                os.environ.get("ProgramFiles", ""),
                "Google",
                "Chrome",
                "Application",
                "chrome.exe",
            ),
            os.path.join(
                os.environ.get("ProgramFiles(x86)", ""),
                "Google",
                "Chrome",
                "Application",
                "chrome.exe",
            ),
        ]
        if not any(os.path.exists(p) for p in paths):
            warn("Chrome not found, using edge")
            DEVICE = "edge"


def deps_hash():
    """Hash pubspec.yaml (and pubspec.lock if present) as a dep cache key."""
    h = hashlib.md5()
    for name in ("pubspec.yaml", "pubspec.lock"):
        path = os.path.join(ROOT, name)
        if os.path.exists(path):
            with open(path, "rb") as f:
                h.update(f.read())
    return h.hexdigest()


def check_deps():
    hash_file = os.path.join(ROOT, ".pub_hash")
    cur_hash = deps_hash()
    if os.path.exists(hash_file):
        try:
            with open(hash_file, "r") as f:
                if f.read().strip() == cur_hash:
                    info("Deps up to date")
                    return True
        except OSError:
            pass
    info("Getting dependencies...")
    r = run_flutter(["pub", "get"], cwd=ROOT)
    if r.returncode != 0:
        err("Failed to install deps")
        return False
    with open(hash_file, "w") as f:
        f.write(deps_hash())
    ok("Deps ready")
    return True


def port_in_use(p):
    try:
        with socket.create_connection((HOST, p), timeout=1):
            return True
    except OSError:
        return False


def find_port():
    port = PORT_START
    while port_in_use(port):
        pport(f"Port {port} is in use, trying next...")
        port += 1
    return port


def _windows_kernel32():
    """Return the Win32 API with proper prototypes (avoids handle truncation)."""
    kernel32 = ctypes.windll.kernel32
    kernel32.OpenProcess.restype = ctypes.wintypes.HANDLE
    kernel32.OpenProcess.argtypes = [ctypes.wintypes.DWORD, ctypes.wintypes.BOOL, ctypes.wintypes.DWORD]
    kernel32.GetExitCodeProcess.restype = ctypes.wintypes.BOOL
    kernel32.GetExitCodeProcess.argtypes = [ctypes.wintypes.HANDLE, ctypes.POINTER(ctypes.wintypes.DWORD)]
    kernel32.CloseHandle.restype = ctypes.wintypes.BOOL
    kernel32.CloseHandle.argtypes = [ctypes.wintypes.HANDLE]
    kernel32.QueryFullProcessImageNameW.restype = ctypes.wintypes.BOOL
    kernel32.QueryFullProcessImageNameW.argtypes = [
        ctypes.wintypes.HANDLE,
        ctypes.wintypes.DWORD,
        ctypes.wintypes.LPWSTR,
        ctypes.POINTER(ctypes.wintypes.DWORD),
    ]
    return kernel32


def process_alive(pid):
    """Check whether a PID is still running (cross-platform)."""
    if platform.system() == "Windows":
        # os.kill(pid, 0) is unreliable on Windows, and OpenProcess alone
        # can succeed on a process that has already exited but is not yet
        # reaped, so confirm via GetExitCodeProcess (STILL_ACTIVE = 259).
        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        STILL_ACTIVE = 259
        kernel32 = _windows_kernel32()
        handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if not handle:
            return False
        try:
            code = ctypes.wintypes.DWORD()
            if not kernel32.GetExitCodeProcess(handle, ctypes.byref(code)):
                return True  # cannot determine: assume alive
            return code.value == STILL_ACTIVE
        finally:
            kernel32.CloseHandle(handle)
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def _windows_process_name(pid):
    """Executable name of a Windows process, or None if it cannot be read."""
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    kernel32 = _windows_kernel32()
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        return None
    try:
        size = ctypes.wintypes.DWORD(1024)
        buf = ctypes.create_unicode_buffer(1024)
        if not kernel32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
            return None
        return os.path.basename(buf.value).lower()
    finally:
        kernel32.CloseHandle(handle)


def kill_process(pid, force=False):
    """Terminate a process.

    On Windows this always kills the whole tree, because the flutter.bat
    wrapper (cmd.exe) spawns dart.exe as a child that would otherwise linger
    on the port, and console processes can only be terminated forcefully.
    On POSIX, `force` decides between SIGTERM and SIGKILL.
    """
    if platform.system() == "Windows":
        subprocess.run(
            ["taskkill", "/F", "/T", "/PID", str(pid)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    else:
        try:
            os.kill(pid, signal.SIGKILL if force else signal.SIGTERM)
        except OSError:
            pass


def stop_old():
    pid_file = os.path.join(ROOT, ".flutter_pid")
    if not os.path.exists(pid_file):
        return
    try:
        with open(pid_file, "r") as f:
            pid = int(f.read().strip())
    except (ValueError, OSError):
        pid = None
    if pid and process_alive(pid):
        # Windows reuses PIDs; a stale pid file must not kill an unrelated
        # process tree, so verify the image name before doing anything.
        if platform.system() == "Windows":
            name = _windows_process_name(pid)
            if name and name not in ("cmd.exe", "dart.exe") and not name.startswith("flutter"):
                warn(f"PID {pid} now belongs to '{name}', not a previous flutter run — skipping")
                os.remove(pid_file)
                return
        warn(f"Stopping old service (PID: {pid})...")
        kill_process(pid)
        # Wait up to ~3s for the process to go away, then force-kill (POSIX).
        for _ in range(15):
            if not process_alive(pid):
                break
            time.sleep(0.2)
        else:
            kill_process(pid, force=True)
            time.sleep(0.5)
        if process_alive(pid):
            err(f"Failed to stop PID {pid} (protected or elevated?)")
        else:
            ok("Old service stopped")
    elif pid:
        info("Removing stale PID file")
    try:
        os.remove(pid_file)
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Textual TUI
# ---------------------------------------------------------------------------


def _detect_dark_mode():
    """Detect Windows dark/light mode. Returns True for dark, False for light."""
    if platform.system() == "Windows":
        try:
            import winreg

            k = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            )
            v, _ = winreg.QueryValueEx(k, "AppsUseLightTheme")
            winreg.CloseKey(k)
            return v == 0
        except Exception:
            pass
    return True


class FlutterTUI(App):
    dark = _detect_dark_mode()
    """Textual TUI for Flutter web dev with selectable output."""

    TITLE = "Flutter Web Dev"
    CSS = """
    Screen {
        layout: vertical;
    }

    TextArea {
        height: 1fr;
        border: none;
        padding: 0 1;
    }

    #button-bar {
        height: auto;
        dock: bottom;
        background: $panel;
        padding: 0 1;
    }

    Button {
        width: 1fr;
        min-width: 0;
        margin: 0 1;
    }
    """

    BINDINGS = [
        Binding("r", "send_cmd('r')", "Hot Reload", show=True),
        Binding("ctrl+r", "send_cmd('R')", "Hot Restart", show=True),
        Binding("c", "clear", "Clear", show=True),
        Binding("h", "send_cmd('h')", "Help", show=True),
        Binding("q", "do_quit", "Quit", show=True),
        Binding("d", "send_cmd('d')", "Detach", show=True),
    ]

    def __init__(self, port: int, device: str):
        super().__init__()
        self.port = port
        self.device = device
        self.flutter_proc: asyncio.subprocess.Process | None = None
        self._reader_task: asyncio.Task | None = None
        self._auto_scroll = True
        self._exit_reported = False
        self._alive_interval = None
        self._scroll_interval = None
        # Plain-text log file as secondary fallback
        self._log_path = os.path.join(ROOT, ".flutter_web_output.log")
        self._log_file = open(self._log_path, "a", encoding="utf-8")
        self._log_file.write(
            f"\n--- Flutter Web Dev {time.strftime('%Y-%m-%d %H:%M:%S')} ---\n"
        )
        self._log_file.flush()

    # ---- compose ----

    def compose(self):
        yield TextArea(
            id="output", read_only=True, show_line_numbers=False, soft_wrap=True
        )
        with Horizontal(id="button-bar"):
            yield Button("Reload", id="r", variant="primary")
            yield Button("Restart", id="R", variant="warning")
            yield Button("Clear", id="c")
            yield Button("Help", id="h")
            yield Button("Detach", id="d")
            yield Button("Quit", id="q", variant="error")

    # ---- helpers ----

    def _writelog(self, text: str):
        """Append a line to the log file and the TextArea (plain text).

        TextArea does not parse rich markup, so all lines are written as
        plain text to keep screen and log file identical.
        """
        # Log file first: it must survive even if the widget is gone.
        try:
            self._log_file.write(text + "\n")
            self._log_file.flush()
        except (OSError, ValueError):
            pass
        try:
            ta = self.query_one("#output", TextArea)
        except NoMatches:
            return
        ta.insert(text + "\n", location=ta.document.end)
        # Keep memory bounded: drop the oldest lines past the cap. The trim
        # rebuilds the TextArea, so allow TRIM_SLACK extra lines to amortize
        # it. Trailing empty lines are artifacts of appending "text\n":
        # strip them before slicing, then restore exactly one via the final
        # "\n" so later inserts at document.end start on a fresh line.
        if ta.document.line_count > MAX_OUTPUT_LINES + TRIM_SLACK:
            lines = list(ta.document.lines)
            while lines and lines[-1] == "":
                lines.pop()
            keep = "\n".join(lines[-MAX_OUTPUT_LINES:]) + "\n"
            ta.load_text(keep)
        # Auto-scroll to latest if at bottom
        if self._auto_scroll:
            end = ta.document.end
            ta.cursor_location = end
            ta.scroll_end(animate=False)

    def _check_scroll_pos(self):
        """Pause auto-scroll when user scrolls up; resume when back at bottom."""
        ta = self.query_one("#output", TextArea)
        if ta.max_scroll_y is None:
            return
        at_bottom = ta.scroll_y >= ta.max_scroll_y - 0.5
        if at_bottom and not self._auto_scroll:
            self._auto_scroll = True
            end = ta.document.end
            ta.cursor_location = end
            ta.scroll_end(animate=False)
        elif not at_bottom and self._auto_scroll:
            self._auto_scroll = False

    # ---- lifecycle ----

    async def on_mount(self):
        cmd = [
            "flutter",
            "run",
            "-d",
            self.device,
            "--web-port",
            str(self.port),
            "--web-hostname",
            HOST,
            "--dart-define",
            f"FLUTTER_WEB_PORT={self.port}",
        ]
        if platform.system() == "Windows":
            cmd[0] = "flutter.bat"

        self._writelog(f"Starting: {' '.join(cmd)}")
        self._writelog(f"Log also saved to: {self._log_path}")

        try:
            self.flutter_proc = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=ROOT,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )
        except Exception as e:
            self._writelog(f"Failed to start flutter: {e}")
            return

        # Save PID for external cleanup
        pid_file = os.path.join(ROOT, ".flutter_pid")
        try:
            with open(pid_file, "w") as f:
                f.write(str(self.flutter_proc.pid))
        except OSError:
            pass

        self._reader_task = asyncio.create_task(self._reader())
        self._alive_interval = self.set_interval(2.0, self._check_alive)
        self._scroll_interval = self.set_interval(0.3, self._check_scroll_pos)

    async def on_unmount(self):
        """Cleanup when TUI closes."""
        await self._cleanup_flutter()
        try:
            self._log_file.close()
        except Exception:
            pass

    # ---- flutter reader ----

    async def _reader(self):
        """Stream flutter stdout to the log.

        Handles carriage-return progress output (keeps only the latest
        segment per line) and decodes incrementally so multi-byte UTF-8
        characters split across chunk boundaries survive.
        """
        decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        buf = ""
        while self.flutter_proc and self.flutter_proc.stdout:
            try:
                chunk = await self.flutter_proc.stdout.read(4096)
            except Exception:
                break
            if not chunk:
                break
            buf += decoder.decode(chunk)
            lines = buf.split("\n")
            buf = lines.pop()
            for line in lines:
                # Tolerate CRLF line endings, and for carriage-return
                # progress output keep only the latest segment.
                line = line.rstrip("\r").split("\r")[-1].rstrip()
                if line:
                    self._writelog(line)
        tail = buf + decoder.decode(b"", final=True)
        tail = tail.rstrip("\r").split("\r")[-1].rstrip()
        if tail:
            self._writelog(tail)
        self._report_exit("Flutter process ended.")

    def _report_exit(self, msg: str):
        """Report process exit exactly once and stop housekeeping timers."""
        if self._exit_reported:
            return
        self._exit_reported = True
        if self._alive_interval:
            self._alive_interval.stop()
        if self._scroll_interval:
            self._scroll_interval.stop()
        self._writelog(msg)

    def _check_alive(self):
        if self.flutter_proc and self.flutter_proc.returncode is not None:
            self._report_exit("Flutter process has exited.")

    # ---- actions ----

    async def action_send_cmd(self, cmd: str):
        """Send a single-character command to flutter's stdin."""
        if not (
            self.flutter_proc
            and self.flutter_proc.stdin
            and self.flutter_proc.returncode is None
        ):
            self._writelog(f"Cannot send '{cmd}': flutter is not running.")
            return
        try:
            self.flutter_proc.stdin.write(f"{cmd}\n".encode())
            await self.flutter_proc.stdin.drain()
        except Exception:
            self._writelog(f"Failed to send '{cmd}' to flutter.")

    def action_clear(self):
        """Clear the output."""
        self.query_one("#output", TextArea).text = ""
        self._auto_scroll = True

    async def action_do_quit(self):
        """Gracefully quit flutter and close the TUI."""
        self._writelog("Shutting down...")
        await self._cleanup_flutter()
        self.exit(0)

    # ---- button handler ----

    async def on_button_pressed(self, event: Button.Pressed):
        btn_id = event.button.id
        if btn_id == "q":
            await self.action_do_quit()
        elif btn_id == "c":
            self.action_clear()
        elif btn_id:
            await self.action_send_cmd(btn_id)

    # ---- helpers ----

    async def _cleanup_flutter(self):
        """Try to stop flutter gracefully, then force-kill if needed."""
        # Cancel reader task first to avoid pipe I/O after process death
        if self._reader_task and not self._reader_task.done():
            self._reader_task.cancel()
            try:
                await self._reader_task
            except asyncio.CancelledError:
                pass
            self._reader_task = None

        if self.flutter_proc and self.flutter_proc.returncode is None:
            try:
                self.flutter_proc.stdin.write(b"q\n")
                await self.flutter_proc.stdin.drain()
            except Exception:
                pass
            try:
                await asyncio.wait_for(self.flutter_proc.wait(), timeout=3)
            except asyncio.TimeoutError:
                pass
            if self.flutter_proc.returncode is None:
                # Force-kill: on Windows kill the whole tree, because
                # flutter.bat (cmd.exe) leaves dart.exe behind on the port.
                if platform.system() == "Windows":
                    subprocess.run(
                        ["taskkill", "/F", "/T", "/PID", str(self.flutter_proc.pid)],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                else:
                    try:
                        self.flutter_proc.kill()
                    except ProcessLookupError:
                        pass
                try:
                    await asyncio.wait_for(self.flutter_proc.wait(), timeout=5)
                except asyncio.TimeoutError:
                    pass
            self.flutter_proc = None
        pid_file = os.path.join(ROOT, ".flutter_pid")
        try:
            os.remove(pid_file)
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def pause_on_error():
    """Wait for Enter so the console doesn't close instantly, then exit 1."""
    try:
        input("Press Enter to exit...")
    except EOFError:
        pass
    sys.exit(1)


def main():
    print()
    print("=" * 42)
    info("  Flutter Web Quick Start")
    print("=" * 42)
    print()

    if not check_flutter():
        pause_on_error()
    if not check_project():
        pause_on_error()
    check_chrome()
    stop_old()
    if not check_deps():
        pause_on_error()

    port = find_port()
    pport(f"Using port: {port}")

    # Launch Textual TUI
    app = FlutterTUI(port=port, device=DEVICE)
    app.run()


if __name__ == "__main__":
    main()
