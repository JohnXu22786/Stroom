#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import asyncio
import hashlib
import os
import platform
import re
import socket
import subprocess
import sys
import time

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.widgets import Button, TextArea

PORT = 7397
HOST = "localhost"
DEVICE = "chrome"
ROOT = os.path.dirname(os.path.abspath(__file__))
MAX_PORT = 7410

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


def run_flutter(args, cwd=None, capture=True):
    path = cwd or ROOT
    if platform.system() == "Windows":
        cmd = ["flutter.bat"] + args
    else:
        cmd = ["flutter"] + args
    if capture:
        return subprocess.run(cmd, cwd=path, capture_output=True, text=True, timeout=60)
    else:
        return subprocess.Popen(cmd, cwd=path)


def check_flutter():
    try:
        r = run_flutter(["--version"])
        if r.returncode == 0:
            v = r.stdout.split(chr(10))[0]
            info("Flutter: " + v)
            return True
    except:
        pass
    err("Flutter not found")
    return False


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


def check_deps():
    hash_file = os.path.join(ROOT, ".pub_hash")
    pub = os.path.join(ROOT, "pubspec.yaml")
    with open(pub, "rb") as f:
        cur_hash = hashlib.md5(f.read()).hexdigest()
    if os.path.exists(hash_file):
        with open(hash_file, "r") as f:
            if f.read().strip() == cur_hash:
                info("Deps up to date")
                return True
    info("Getting dependencies...")
    r = run_flutter(["pub", "get"], cwd=ROOT)
    if r.returncode == 0:
        with open(hash_file, "w") as f:
            f.write(cur_hash)
        ok("Deps ready")
        return True
    err("Failed to install deps")
    return False


def port_in_use(p):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(1)
    try:
        r = s.connect_ex((HOST, p))
        s.close()
        return r == 0
    except:
        return False


def find_port():
    p = PORT
    while p <= MAX_PORT:
        if not port_in_use(p):
            return p
        pport("Port " + str(p) + " in use, trying next...")
        p += 1
    err("No available port in " + str(PORT) + "-" + str(MAX_PORT))
    return None


def stop_old():
    pid_file = os.path.join(ROOT, ".flutter_pid")
    if os.path.exists(pid_file):
        try:
            with open(pid_file, "r") as f:
                pid = int(f.read().strip())
            try:
                os.kill(pid, 0)
                warn("Stopping old service (PID: " + str(pid) + ")...")
                os.kill(pid, signal.SIGTERM)
                time.sleep(2)
                try:
                    os.kill(pid, 0)
                    os.kill(pid, signal.SIGKILL)
                except:
                    pass
                ok("Old service stopped")
            except:
                pass
        except:
            pass
        try:
            os.remove(pid_file)
        except:
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
        """Write text to TextArea and append plain-text to log file."""
        ta = self.query_one("#output", TextArea)
        ta.insert(text + "\n", location=ta.document.end)
        # Log file (plain text, stripped of markup)
        plain = re.sub(r"\[/?[^\]]*\]", "", text)
        self._log_file.write(plain + "\n")
        self._log_file.flush()
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

        self._writelog(f"[bold]Starting:[/bold] {' '.join(cmd)}")
        self._writelog(f"[dim]Log also saved to: {self._log_path}[/dim]")

        try:
            self.flutter_proc = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=ROOT,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )
        except Exception as e:
            self._writelog(f"[red]Failed to start flutter: {e}[/red]")
            return

        # Save PID for external cleanup
        pid_file = os.path.join(ROOT, ".flutter_pid")
        try:
            with open(pid_file, "w") as f:
                f.write(str(self.flutter_proc.pid))
        except Exception:
            pass

        self._reader_task = asyncio.create_task(self._reader())
        self.set_interval(2.0, self._check_alive)
        self.set_interval(0.3, self._check_scroll_pos)

    async def on_unmount(self):
        """Cleanup when TUI closes."""
        await self._cleanup_flutter()
        try:
            self._log_file.close()
        except Exception:
            pass

    # ---- flutter reader ----

    async def _reader(self):
        while self.flutter_proc and self.flutter_proc.stdout:
            try:
                line = await self.flutter_proc.stdout.readline()
                if not line:
                    break
                text = line.decode("utf-8", errors="replace").rstrip()
                self._writelog(text)
            except Exception:
                break
        self._writelog("[red]Flutter process ended.[/red]")

    def _check_alive(self):
        if self.flutter_proc and self.flutter_proc.returncode is not None:
            self._writelog("[red]Flutter process has exited.[/red]")

    # ---- actions ----

    async def action_send_cmd(self, cmd: str):
        """Send a single-character command to flutter's stdin."""
        if (
            self.flutter_proc
            and self.flutter_proc.stdin
            and self.flutter_proc.returncode is None
        ):
            try:
                self.flutter_proc.stdin.write(f"{cmd}\n".encode())
                await self.flutter_proc.stdin.drain()
            except Exception:
                pass

    def action_clear(self):
        """Clear the output."""
        self.query_one("#output", TextArea).text = ""

    async def action_do_quit(self):
        """Gracefully quit flutter and close the TUI."""
        self._writelog("[yellow]Shutting down...[/yellow]")
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
        if self.flutter_proc and self.flutter_proc.returncode is None:
            try:
                self.flutter_proc.stdin.write(b"q\n")
                await self.flutter_proc.stdin.drain()
            except Exception:
                pass
            try:
                await asyncio.wait_for(self.flutter_proc.wait(), timeout=3)
            except (asyncio.TimeoutError, Exception):
                try:
                    self.flutter_proc.kill()
                except Exception:
                    pass
        pid_file = os.path.join(ROOT, ".flutter_pid")
        try:
            os.remove(pid_file)
        except Exception:
            pass


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main():
    print()
    print("=" * 42)
    info("  Flutter Web Quick Start")
    print("=" * 42)
    print()

    if not check_flutter():
        input("Press Enter to exit...")
        sys.exit(1)
    if not check_project():
        input("Press Enter to exit...")
        sys.exit(1)
    check_chrome()
    stop_old()
    if not check_deps():
        input("Press Enter to exit...")
        sys.exit(1)

    port = find_port()
    if not port:
        input("Press Enter to exit...")
        sys.exit(1)

    if port != PORT:
        pport(f"Using port: {port} (original in use)")
    else:
        pport(f"Using port: {port}")

    # Launch Textual TUI
    app = FlutterTUI(port=port, device=DEVICE)
    app.run()


if __name__ == "__main__":
    main()
