/// Layered HTTP timeout policy for flow block API calls.
///
/// Timeouts are scoped to the phase they guard, so a slow-but-healthy
/// server is never killed by an artificial total deadline:
/// - [connectTimeoutDefault] — TCP connect phase (can't reach the host:
///   DNS failure, refused, blackhole). Fail fast.
/// - [sendTimeoutForBytes] — request-body upload phase (stalled upload is
///   a connection-level failure). Scaled by body size so slow but
///   progressing uploads are not dropped.
/// - [receiveTimeoutFallback] — response phase. Deliberately long: the
///   client cannot distinguish "server computing slowly" from "server
///   hung", and the app's own pages run with no response timeout at all
///   (see asr_service.dart "No timeouts"). This bound exists only so a
///   truly hung server cannot brick the flow system's global run lock.
library;

/// TCP connect timeout — fail fast when the host is unreachable.
const Duration connectTimeoutDefault = Duration(seconds: 30);

/// Response-phase fallback bound (60 min). Slow transcriptions/syntheses
/// can legitimately take tens of minutes; only a >1h silent server hits
/// this.
const Duration receiveTimeoutFallback = Duration(minutes: 60);

/// Upload-phase timeout scaled by request body size:
/// 1 minute base + 2 s per MiB, capped at 15 minutes.
///
/// A stalled upload (connection died mid-body) fails fast; a slow but
/// progressing upload of a large audio file gets proportional headroom.
Duration sendTimeoutForBytes(int requestBodyBytes) {
  final base = const Duration(minutes: 1);
  final perMiB = Duration(seconds: 2) * (requestBodyBytes ~/ (1024 * 1024));
  final total = base + perMiB;
  const cap = Duration(minutes: 15);
  return total > cap ? cap : total;
}
