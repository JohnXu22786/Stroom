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
        server_log.close()
        server_log_path.unlink(missing_ok=True)
