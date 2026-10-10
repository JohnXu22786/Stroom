import { createContext, useContext, useEffect, useRef, useState } from "react";
import {
  CodeBlock,
  IconCopyOutlineRegular,
  IconDownloadOutlineRegular,
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
  lang = lang?.toLowerCase();
  streaming =
    streaming && !fenceComplete(context?.source, sourceStart, sourceEnd);
  const [wrap, setWrap] = useState(false);
  const [source, setSource] = useState(false);
  const action = (name) => context?.action(name, { sourceStart, sourceEnd });
  const special = lang === "html" || lang === "mermaid";
  const htmlTitle =
    lang === "html" ? /<title[^>]*>([^<]*)<\/title>/i.exec(code)?.[1] : null;
  return (
    <section
      className={`code-card ${wrap ? "wrap" : ""}`}
      data-source-start={sourceStart}
    >
      <header>
        <span>
          {htmlTitle || lang || "代码"}
          {streaming ? " · 生成中" : ""}
        </span>
        <div>
          <button
            title="复制代码"
            aria-label="复制代码"
            onClick={() => action("copyCode")}
          >
            <IconCopyOutlineRegular size={16} />
          </button>
          <button
            title="保存代码"
            aria-label="保存代码"
            onClick={() => action("saveCode")}
          >
            <IconDownloadOutlineRegular size={16} />
          </button>
          <button
            title="自动换行"
            aria-label="自动换行"
            aria-pressed={wrap}
            onClick={() => setWrap((v) => !v)}
          >
            <IconWrapLinesOutlineRegular size={16} />
          </button>
          {special && (
            <button onClick={() => setSource((v) => !v)}>
              {source ? "内容" : "源码"}
            </button>
          )}
          <button
            data-action={special ? lang : "code"}
            title="全屏"
            aria-label="全屏"
            disabled={special && streaming}
            onClick={() => action(special ? lang : "code")}
          >
            ⛶
          </button>
        </div>
      </header>
      {lang === "html" && !source ? (
        <div className="html-card">
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
      ) : lang === "mermaid" && !source && !streaming ? (
        <Diagram code={code} />
      ) : (
        <CodeBlock
          code={code}
          lang={lang}
          streaming={streaming}
          lineNumbers
          showHeader={false}
          copyLabel="复制"
          copiedLabel="已复制"
        />
      )}
    </section>
  );
}
