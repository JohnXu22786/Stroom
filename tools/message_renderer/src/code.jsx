import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";
import {
  CodeBlock,
  IconCopyOutlineRegular,
  IconCodeOutlineRegular,
  IconDownloadOutlineRegular,
  IconFullscreenOutlineRegular,
  IconWrapLinesOutlineRegular,
} from "@deepseek-ai/dsh-client-ui-primitives";
import mermaid from "mermaid";

import { fenceComplete } from "./code-fence.js";
import { buildHtmlPreviewDocument } from "./html-preview.js";

export const MessageContext = createContext(null);
mermaid.initialize({
  startOnLoad: false,
  securityLevel: "strict",
  flowchart: { htmlLabels: false },
  suppressErrorRendering: true,
});
let diagramId = 0;

function Diagram({ code }) {
  const element = useRef(null);
  const [error, setError] = useState(false);
  const [scale, setScale] = useState(1);
  useEffect(() => {
    let active = true;
    mermaid
      .render(`stroom-diagram-${++diagramId}`, code)
      .then(({ svg }) => {
        if (active && element.current) {
          element.current.innerHTML = svg;
          setError(false);
        }
      })
      .catch(() => {
        if (active) setError(true);
      });
    return () => {
      active = false;
    };
  }, [code]);
  return (
    <div className="diagram">
      <div className="diagram-controls">
        <button
          onClick={() => setScale((s) => Math.max(0.25, s - 0.25))}
          aria-label="缩小"
        >
          −
        </button>
        <button onClick={() => setScale(1)}>重置</button>
        <button
          onClick={() => setScale((s) => Math.min(3, s + 0.25))}
          aria-label="放大"
        >
          ＋
        </button>
      </div>
      {error && <p>图表暂时无法绘制，可以查看源码。</p>}
      <div className="diagram-pan" hidden={error}>
        <div
          ref={element}
          style={{
            transform: `scale(${scale})`,
            transformOrigin: "top left",
          }}
        />
      </div>
    </div>
  );
}

export function StroomCode({ code, lang, streaming, sourceStart, sourceEnd }) {
  const context = useContext(MessageContext);
  const host = useRef(null);
  lang = lang?.toLowerCase();
  const htmlFenceClosed =
    lang === "html" &&
    fenceComplete(context?.source, sourceStart, sourceEnd);
  streaming =
    streaming && !fenceComplete(context?.source, sourceStart, sourceEnd);
  const [wrap, setWrap] = useState(() =>
    ["markdown", "md", "text", "plaintext", "txt"].includes(lang),
  );
  const [source, setSource] = useState(false);
  const [toolbar, setToolbar] = useState(null);
  const [htmlPreview, setHtmlPreview] = useState({
    code: null,
    status: "loading",
  });
  const action = (name) => context?.action(name, { sourceStart, sourceEnd });
  const special = lang === "html" || lang === "mermaid";
  const canPreviewHtml = htmlFenceClosed && !streaming;
  const htmlStatus = htmlPreview.code === code ? htmlPreview.status : "loading";
  const showingHtmlPreview =
    canPreviewHtml && htmlStatus !== "error" && htmlStatus !== "tall";
  const showingTallHtml = canPreviewHtml && htmlStatus === "tall";
  const showingDiagram = lang === "mermaid" && !source && !streaming;
  const showingPreview = showingHtmlPreview || showingDiagram;
  useEffect(() => {
    setToolbar(
      showingPreview
        ? null
        : host.current?.querySelector("[data-code-block-banner]") || null,
    );
  }, [showingPreview, lang]);
  return (
    <section
      ref={host}
      className={
        `stroom-code-card${showingHtmlPreview ? " stroom-inline-html-card" : ""}`
      }
      data-source-start={sourceStart}
    >
      {showingTallHtml ? (
        <div className="html-fullscreen-fallback">
          <button data-action="html" onClick={() => action("html")}>
            内容较长，打开全屏预览
          </button>
        </div>
      ) : showingHtmlPreview ? (
        <HtmlPreview
          key={`${sourceStart}:${code}`}
          code={code}
          onStatus={setHtmlPreview}
        />
      ) : showingDiagram ? (
        <>
          <CodeActions
            className="stroom-code-actions-floating"
            action={action}
            special={special}
            lang={lang}
            streaming={streaming}
            wrap={wrap}
            setWrap={setWrap}
            source={source}
            setSource={setSource}
          />
          <Diagram code={code} />
        </>
      ) : (
        <>
          {toolbar && createPortal(
            <CodeActions
              className="stroom-code-actions"
              action={action}
              special={special}
              lang={lang}
              streaming={streaming}
              wrap={wrap}
              setWrap={setWrap}
              source={source}
              setSource={setSource}
              htmlFenceClosed={htmlFenceClosed}
            />,
            toolbar,
          )}
          <CodeBlock
            code={code}
            lang={lang}
            streaming={streaming}
            className="stroom-dsh-code-block"
            toolbarLabels={{
              codeLabel: "代码块",
              wrapLabel: "自动换行",
              unwrapLabel: "取消自动换行",
            }}
            wrap={wrap}
            lineNumbers
            copyLabel="复制"
            copiedLabel="已复制"
          />
        </>
      )}
    </section>
  );
}

function HtmlPreview({ code, onStatus }) {
  const frame = useRef(null);
  const [token] = useState(() =>
    globalThis.crypto?.randomUUID?.() ||
    `stroom-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`,
  );
  const [contentHeight, setContentHeight] = useState(1);
  const [viewportHeight, setViewportHeight] = useState(1);
  const [srcDoc, setSrcDoc] = useState("");
  useEffect(() => {
    const transcript = document.getElementById("transcript");
    const updateViewport = () =>
      setViewportHeight(
        Math.max(1, transcript?.clientHeight || window.innerHeight),
      );
    updateViewport();
    const observer = transcript && window.ResizeObserver
      ? new ResizeObserver(updateViewport)
      : null;
    observer?.observe(transcript);
    window.addEventListener("resize", updateViewport);
    return () => {
      observer?.disconnect();
      window.removeEventListener("resize", updateViewport);
    };
  }, []);
  useEffect(() => {
    const onMessage = (event) => {
      if (event.source !== frame.current?.contentWindow) return;
      const message = event.data;
      if (
        !message ||
        message.type !== "stroom-html-preview" ||
        message.token !== token
      )
        return;
      if (message.kind === "error") {
        onStatus({ code, status: "error" });
      } else if (
        message.kind === "height" &&
        Number.isFinite(message.height) &&
        message.height >= 0 &&
        Number.isFinite(message.viewportHeight)
      ) {
        const height = Math.ceil(message.height);
        const transcript = document.getElementById("transcript");
        const viewportHeight = Math.max(
          1,
          transcript?.clientHeight || window.innerHeight,
        );
        // A message queued before the iframe resized describes the old CSS
        // viewport. Wait for its fresh resize measurement before deciding
        // whether this preview still fits inline.
        if (message.viewportHeight !== viewportHeight) return;
        setContentHeight(Math.max(1, height));
        const status = height > viewportHeight ? "tall" : "inline";
        onStatus((current) =>
          current.code === code &&
          current.status === status &&
          current.height === height
            ? current
            : { code, status, height },
        );
      }
    };
    window.addEventListener("message", onMessage);
    setSrcDoc(buildHtmlPreviewDocument(code, token));
    return () => {
      window.removeEventListener("message", onMessage);
    };
  }, [code, onStatus, token]);
  return (
    <div
      className="stroom-html-preview-window"
      style={{ height: Math.min(contentHeight, viewportHeight) }}
    >
      <iframe
        ref={frame}
        className="stroom-html-preview"
        title="HTML 预览"
        sandbox="allow-scripts"
        data-preview-token={token}
        srcDoc={srcDoc || undefined}
        style={{ height: viewportHeight }}
      />
    </div>
  );
}

function CodeActions({
  className,
  action,
  special,
  lang,
  streaming,
  wrap,
  setWrap,
  source,
  setSource,
  htmlFenceClosed,
}) {
  return (
    <div className={className} aria-label="代码块操作">
      <button
        className="stroom-code-action"
        title="复制代码"
        aria-label="复制代码"
        onClick={() => action("copyCode")}
      >
        <IconCopyOutlineRegular size={16} />
      </button>
      <button
        className="stroom-code-action"
        title="保存代码"
        aria-label="保存代码"
        onClick={() => action("saveCode")}
      >
        <IconDownloadOutlineRegular size={16} />
      </button>
      <button
        className="stroom-code-action"
        title="自动换行"
        aria-label="自动换行"
        aria-pressed={wrap}
        onClick={() => setWrap((value) => !value)}
      >
        <IconWrapLinesOutlineRegular size={16} />
      </button>
      {lang === "mermaid" && (
        <button
          className="stroom-code-action"
          title={source ? "查看图表" : "查看源码"}
          aria-label={source ? "查看图表" : "查看源码"}
          onClick={() => setSource((value) => !value)}
        >
          <IconCodeOutlineRegular size={16} />
        </button>
      )}
      <button
        className="stroom-code-action"
        data-action={special ? lang : "code"}
        title="全屏"
        aria-label="全屏"
        disabled={
          special && (streaming || (lang === "html" && !htmlFenceClosed))
        }
        onClick={() => action(special ? lang : "code")}
      >
        <IconFullscreenOutlineRegular size={16} />
      </button>
    </div>
  );
}
