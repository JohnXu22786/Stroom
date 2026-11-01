function measurementScript(token) {
  const encodedToken = JSON.stringify(token).replace(/</g, "\\u003c");
  return `(() => {
    const token = ${encodedToken};
    const notify = (kind, extra = {}) => parent.postMessage({
      type: "stroom-html-preview",
      token,
      kind,
      ...extra,
    }, "*");
    let queued = false;
    let lastHeight = null;
    let lastViewportHeight = null;
    const measure = () => {
      queued = false;
      const root = document.documentElement;
      const body = document.body;
      const viewportHeight = Math.max(1, window.innerHeight);
      const rootMinHeight = parseFloat(getComputedStyle(root).minHeight) || 0;
      const bodyMinHeight = parseFloat(getComputedStyle(body).minHeight) || 0;
      const overflowingDocument =
        root.scrollHeight > viewportHeight ? root.scrollHeight : 0;
      const height = Math.ceil(Math.max(
        body?.scrollHeight || 0,
        body?.offsetHeight || 0,
        rootMinHeight,
        bodyMinHeight,
        overflowingDocument,
      ));
      if (
        height === lastHeight &&
        viewportHeight === lastViewportHeight
      )
        return;
      lastHeight = height;
      lastViewportHeight = viewportHeight;
      notify("height", { height, viewportHeight });
    };
    const scheduleMeasure = () => {
      if (queued) return;
      queued = true;
      requestAnimationFrame(measure);
    };
    addEventListener("error", (event) => {
      if (event.target === window || event.target?.tagName === "SCRIPT")
        notify("error");
    }, true);
    addEventListener("unhandledrejection", () => notify("error"));
    const observe = () => {
      if (window.ResizeObserver) {
        const resizeObserver = new ResizeObserver(scheduleMeasure);
        resizeObserver.observe(document.documentElement);
        if (document.body) resizeObserver.observe(document.body);
      }
      if (window.MutationObserver) {
        new MutationObserver(scheduleMeasure).observe(document.documentElement, {
          attributes: true,
          childList: true,
          characterData: true,
          subtree: true,
        });
      }
      scheduleMeasure();
    };
    document.addEventListener("DOMContentLoaded", observe, { once: true });
    document.addEventListener("load", scheduleMeasure, true);
    addEventListener("load", scheduleMeasure);
    addEventListener("resize", scheduleMeasure);
    if (document.readyState !== "loading") observe();
  })();`;
}

export function buildHtmlPreviewDocument(
  html,
  token,
  DOMParserClass = DOMParser,
) {
  const document = new DOMParserClass()
    .parseFromString(String(html ?? ""), "text/html");
  const monitor = document.createElement("script");
  monitor.setAttribute("data-stroom-preview-monitor", "");
  monitor.textContent = measurementScript(token);
  document.head.prepend(monitor);
  return `<!doctype html>\n${document.documentElement.outerHTML}`;
}
