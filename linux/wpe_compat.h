#ifndef STROOM_WPE_COMPAT_H_
#define STROOM_WPE_COMPAT_H_

#include <wpe/webkit.h>

// The beta plugin calls this optional WPE 2.50 API unconditionally. Older
// engines cannot supply the page's meta theme color; report it as unavailable.
#if !WEBKIT_CHECK_VERSION(2, 50, 0)
static inline gboolean webkit_web_view_get_theme_color(WebKitWebView*,
                                                       WebKitColor*) {
  return FALSE;
}
#endif

#endif  // STROOM_WPE_COMPAT_H_
