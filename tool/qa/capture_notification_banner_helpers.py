def require_banner_seen(banner_seen, frame_count):
    if not banner_seen:
        raise RuntimeError(
            f"Notification banner was never observed in {frame_count} capture frames."
        )
