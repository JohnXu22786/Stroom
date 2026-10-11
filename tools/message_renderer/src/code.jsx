import { createContext, useContext, useEffect, useRef, useState } from "react";
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
  streaming =
    streaming && !fenceComplete(context?.source, sourceStart, sourceEnd);
  const [wrap, setWrap] = useState(() =>
    ["markdown", "md", "text", "plaintext", "txt"].includes(lang),
  );
  const [source, setSource] = useState(false);
  const [toolbar, setToolbar] = useState(null);
  const action = (name) => context?.action(name, { sourceStart, sourceEnd });
  const special = lang === "html" || lang === "mermaid";
  const htmlTitle =
    lang === "html" ? /<title[^>]*>([^<]*)<\/title>/i.exec(code)?.[1] : null;
  const showingHtmlPreview = lang === "html" && !source;
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
      className="stroom-code-card"
      data-source-start={sourceStart}
    >
      {showingPreview ? (
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
          {showingHtmlPreview ? (
            <div className="html-preview-card">
              <strong>{htmlTitle || "HTML 页面"}</strong>
              <p>{streaming ? "正在生成页面…" : "点击全屏查看页面"}</p>
              <button
                data-action="html"
                disabled={streaming}
                onClick={() => action("html")}
              >
                打开预览
              </button>
            </div>
          ) : (
            <Diagram code={code} />
          )}
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
      {(lang === "html" || lang === "mermaid") && (
        <button
          className="stroom-code-action"
          title={source ? (lang === "html" ? "查看页面" : "查看图表") : "查看源码"}
          aria-label={source ? (lang === "html" ? "查看页面" : "查看图表") : "查看源码"}
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
        disabled={special && streaming}
        onClick={() => action(special ? lang : "code")}
      >
        <IconFullscreenOutlineRegular size={16} />
      </button>
    </div>
  );
}
