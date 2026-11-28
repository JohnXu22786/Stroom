import subprocess


def cleanup_server(server, server_log, server_log_path):
    try:
        server.terminate()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
    finally:
        try:
            server_log.close()
        finally:
            server_log_path.unlink(missing_ok=True)
