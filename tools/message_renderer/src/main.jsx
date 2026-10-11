import { engineReady } from "./highlighter.js";
import { memo, useEffect, useLayoutEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { flushSync } from "react-dom";
import {
  MarkdownText,
  IconCopyOutlineRegular,
  IconDownloadOutlineRegular,
  IconRefreshOutlineRegular,
  IconEditOutlineRegular,
  IconCodeOutlineRegular,
  IconTrashOutlineRegular,
  MarkdownDelegateProvider,
} from "@deepseek-ai/dsh-client-ui-primitives";
import "katex/contrib/mhchem/mhchem.js";
import { MessageContext } from "./code.jsx";
import { Tool } from "./tool.jsx";
import "./style.css";

const labels = {
  code: { copyLabel: "复制", copiedLabel: "已复制" },
  footnotes: "注释",
};
const icons = {
  copy: IconCopyOutlineRegular,
  save: IconDownloadOutlineRegular,
  retry: IconRefreshOutlineRegular,
  edit: IconEditOutlineRegular,
  raw: IconCodeOutlineRegular,
  json: IconCodeOutlineRegular,
  delete: IconTrashOutlineRegular,
};
const titles = {
  copy: "复制",
  save: "保存 Markdown",
  retry: "重新生成",
  edit: "编辑",
  raw: "查看请求与响应",
  json: "检查 JSON",
  delete: "删除",
};
const foldSearchCase = (value) =>
  // JavaScript lowercasing is context-sensitive for Greek final sigma, but
  // search should treat both sigma forms as the same character.
  value.toLowerCase().replace(/\u03c2/g, "\u03c3");
let current = { session: null, messages: [], hasOlder: false, theme: {} };
let search = { query: "" };
let update;
let channel = null;
let follow = false;
let initialPositionPending = true;
let searchDecorations = [];
function clearSearchMarks() {
  for (const { node, text, inserted } of searchDecorations) {
    node.data = text;
    for (const extra of inserted) extra.remove();
  }
  searchDecorations = [];
}
const scroller = () => document.getElementById("transcript");
function send(event) {
  if (window.flutter_inappwebview?.callHandler)
    return window.flutter_inappwebview.callHandler("StroomMessageView", event);
  if (channel) window.parent.postMessage({ channel, event }, "*");
}
function action(messageId, name, extra = {}) {
  send({
    type: "action",
    session: current.session,
    messageId,
    action: name,
    ...extra,
  });
}

function formatMessageTimestamp(value) {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return "";
  const pad = (part) => (part < 10 ? `0${part}` : String(part));
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

const Message = memo(function Message({ message }) {
  const timestamp =
    message.role === "user" ? formatMessageTimestamp(message.createdAt) : "";
  const pendingThumbnailIds = (message.attachments || [])
    .filter((attachment) => attachment.fileType === "image" && !attachment.thumbnail)
    .map((attachment) => attachment.id);
  const pendingThumbnailKey = JSON.stringify(pendingThumbnailIds);
  useEffect(() => {
    for (const attachmentId of pendingThumbnailIds)
      action(message.id, "thumbnail", { attachmentId });
  }, [message.id, pendingThumbnailKey]);
  return (
    <article
      data-message-id={message.id}
      className={`message ${message.role} ${message.error ? "error" : ""}`}
    >
      {message.role === "user" ? (
        message.content?.trim() ? (
          <div className="user-text" data-search-text>
            {message.content}
          </div>
        ) : null
      ) : (
        (message.blocks || []).map((block, index) => (
          <MessageContext.Provider
            key={index}
            value={{
              source: block.type === "text" ? block.text : undefined,
              action: (name, extra) =>
                action(message.id, name, { blockIndex: index, ...extra }),
            }}
          >
            <div data-block-type={block.type}>
              {block.type === "text" && (
                <div data-search-text>
                  <MarkdownText
                    text={block.text}
                    streaming={block.streaming ?? message.streaming}
                    labels={labels}
                  />
                </div>
              )}
              {block.type === "reasoning" && block.text && (
                <button
                  className="reasoning"
                  data-action="reasoning"
                  onClick={() =>
                    action(message.id, "reasoning", { blockIndex: index })
                  }
                >
                  <span
                    className={
                      block.isComplete || !message.streaming ? "" : "pulse"
                    }
                  >
                    ✧
                  </span>{" "}
                  {block.isComplete || !message.streaming
                    ? "推理过程"
                    : "正在思考"}{" "}
                  <span>›</span>
                </button>
              )}
              {block.type === "tool_call" && <Tool block={block} />}
              {block.type === "error" && (
                <p className="error-block">{block.message}</p>
              )}
            </div>
          </MessageContext.Provider>
        ))
      )}
      {!!message.attachments?.length && (
        <div className="attachments">
          {message.attachments.map((a) => (
            <button
              key={a.id}
              className="attachment"
              onClick={() =>
                action(message.id, "attachment", { attachmentId: a.id })
              }
            >
              {a.thumbnail ? <img alt="" src={a.thumbnail} /> : <span>▧</span>}
              <span>{a.fileName}</span>
            </button>
          ))}
        </div>
      )}
      {timestamp && (
        <time className="message-timestamp" dateTime={message.createdAt}>
          {timestamp}
        </time>
      )}
      <footer>
        {(message.actions || []).map((name) => (
          <button
            key={name}
            data-action={name}
            title={titles[name]}
            aria-label={titles[name]}
            onClick={() => action(message.id, name)}
          >
            {(() => {
              const Icon = icons[name];
              return <Icon size={18} />;
            })()}
          </button>
        ))}
        {message.streaming && <span className="pulse">•••</span>}
      </footer>
    </article>
  );
});

function applySearch(emit = true) {
  const root = scroller();
  if (!root) return;
  clearSearchMarks();
  const matches = [];
  if (search.query)
    for (const article of root.querySelectorAll("[data-message-id]")) {
      const nodes = [];
      let text = "",
        previousOwner = null;
      for (const area of article.querySelectorAll("[data-search-text]")) {
        previousOwner = null;
        const walker = document.createTreeWalker(
          area,
          NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT,
          {
            acceptNode: (n) => {
              if (n.nodeType === Node.ELEMENT_NODE)
                return n.matches("br, .code-card, code, .katex, button")
                  ? NodeFilter.FILTER_ACCEPT
                  : NodeFilter.FILTER_SKIP;
              return n.parentElement.closest(".code-card, code, .katex, button")
                ? NodeFilter.FILTER_REJECT
                : NodeFilter.FILTER_ACCEPT;
            },
          },
        );
        while (walker.nextNode()) {
          const node = walker.currentNode;
          if (node.nodeType === Node.ELEMENT_NODE) {
            text += "\n";
            previousOwner = null;
            continue;
          }
          const owner = node.parentElement.closest(
            "p,h1,h2,h3,h4,h5,h6,li,dt,dd,td,th,blockquote,[data-search-text]",
          );
          if (nodes.length && owner !== previousOwner && !text.endsWith("\n"))
            text += "\n";
          nodes.push({ node, offset: text.length });
          text += node.data;
          previousOwner = owner;
        }
      }
      const foldedText = foldSearchCase(text);
      const foldedStartOffsets = [];
      const foldedEndOffsets = [];
      let originalOffset = 0;
      for (const character of text) {
        const foldedLength = foldSearchCase(character).length;
        for (let i = 0; i < foldedLength; i++) {
          foldedStartOffsets.push(originalOffset);
          foldedEndOffsets.push(originalOffset + character.length);
        }
        originalOffset += character.length;
      }
      const query = foldSearchCase(search.query);
      let start = 0,
        occurrence = 0;
      const ranges = [];
      while ((start = foldedText.indexOf(query, start)) >= 0) {
        const end = start + query.length;
        ranges.push({
          start: foldedStartOffsets[start],
          end: foldedEndOffsets[end - 1],
          occurrence,
        });
        matches.push({
          messageId: article.dataset.messageId,
          occurrence: occurrence++,
        });
        start += query.length;
      }
      for (const { node, offset } of nodes) {
        const end = offset + node.length;
        const hits = ranges.filter((r) => r.start < end && r.end > offset);
        if (hits.length) {
          const fragment = document.createDocumentFragment();
          const original = node.data;
          let cursor = 0;
          for (const hit of hits) {
            const from = Math.max(0, hit.start - offset),
              to = Math.min(node.length, hit.end - offset);
            fragment.append(node.data.slice(cursor, from));
            const mark = document.createElement("mark");
            mark.textContent = node.data.slice(from, to);
            if (
              article.dataset.messageId === search.messageId &&
              hit.occurrence === search.occurrence
            )
              mark.className = "current";
            fragment.append(mark);
            cursor = to;
          }
          fragment.append(node.data.slice(cursor));
          const inserted = [...fragment.childNodes];
          node.data = "";
          node.after(fragment);
          searchDecorations.push({ node, text: original, inserted });
        }
      }
    }
  if (emit)
    send({
      type: "searchResults",
      session: current.session,
      query: search.query,
      matches,
    });
  root.querySelector("mark.current")?.scrollIntoView({ block: "center" });
}

function View() {
  const [state, setState] = useState(current);
  update = setState;
  const [atBottom, setBottom] = useState(true);
  useLayoutEffect(() => {
    const e = scroller();
    const observer = new ResizeObserver(() => {
      if (follow) e.scrollTop = e.scrollHeight;
    });
    observer.observe(e.firstElementChild);
    const resized = () => {
      if (follow) e.scrollTop = e.scrollHeight;
    };
    window.addEventListener("resize", resized);
    return () => {
      observer.disconnect();
      window.removeEventListener("resize", resized);
    };
  }, []);
  return (
    <main
      id="transcript"
      onScroll={(e) => {
        const element = e.currentTarget;
        const bottom =
          element.scrollHeight - element.scrollTop - element.clientHeight < 24;
        setBottom(bottom);
        if (bottom && !search.query) follow = true;
      }}
      onPointerDown={(e) => {
        if (e.target === e.currentTarget) follow = false;
      }}
      onKeyDown={(e) => {
        if (["ArrowUp", "PageUp", "Home"].includes(e.key)) follow = false;
      }}
      onWheel={(e) => {
        if (e.deltaY < 0) follow = false;
      }}
      onTouchMove={() => {
        follow = false;
      }}
    >
      <div className="messages">
        {state.hasOlder && (
          <button
            className="load-older"
            onClick={() => send({ type: "loadOlder", session: state.session })}
          >
            加载更早的消息
          </button>
        )}
        {state.messages.map((message) => (
          <Message key={`${state.session}:${message.id}`} message={message} />
        ))}
      </div>
      {!atBottom && (
        <button
          className="to-bottom"
          title="滚动到底部"
          onClick={() => {
            follow = true;
            send({
              type: "scrollBottom",
              session: current.session,
            });
          }}
        >
          ↓
        </button>
      )}
    </main>
  );
}

function receive(command) {
  if (command.type !== "snapshot" && command.session !== current.session)
    return;
  const e = scroller();
  if (command.type === "snapshot" || command.type === "patch") {
    const changedSession = command.session !== current.session;
    const anchor = [...e.querySelectorAll("[data-message-id]")].find(
      (n) => n.offsetTop + n.offsetHeight >= e.scrollTop,
    );
    const distance = anchor ? anchor.offsetTop - e.scrollTop : 0;
    let messages = command.messages;
    if (command.type === "patch") {
      const byId = new Map(current.messages.map((m) => [m.id, m]));
      for (const m of messages) byId.set(m.id, m);
      messages = command.order
        ? command.order.map((id) => byId.get(id)).filter(Boolean)
        : [...byId.values()];
    }
    current = { ...current, ...command, messages };
    if (command.theme) {
      document.documentElement.dataset.theme = command.theme.dark
        ? "dark"
        : "light";
      document.documentElement.style.setProperty(
        "--message-size",
        `${command.theme.fontSize || 16}px`,
      );
      for (const [name, value] of Object.entries(command.theme.colors || {}))
        document.documentElement.style.setProperty(name, value);
    }
    if (changedSession) {
      initialPositionPending = true;
      follow = false;
      search = { query: "" };
    }
    clearSearchMarks();
    flushSync(() => update(current));
    if (
      initialPositionPending &&
      current.historyLoaded !== false &&
      current.messages.length > 0
    ) {
      initialPositionPending = false;
      const lastUser = [...e.querySelectorAll(".user")].at(-1);
      e.scrollTop =
        lastUser && e.scrollHeight - lastUser.offsetTop > e.clientHeight
          ? lastUser.offsetTop
          : e.scrollHeight;
      follow = e.scrollHeight - e.scrollTop - e.clientHeight < 24;
    } else if (follow) e.scrollTop = e.scrollHeight;
    else if (anchor) {
      const next = [...e.querySelectorAll("[data-message-id]")].find(
        (n) => n.dataset.messageId === anchor.dataset.messageId,
      );
      if (next) e.scrollTop = next.offsetTop - distance;
    }
    if (search.query) applySearch();
  } else if (command.type === "search") {
    follow = false;
    search = command;
    applySearch(command.emitResults !== false);
  } else if (command.type === "scrollBottom") {
    follow = true;
    e.scrollTo({
      top: e.scrollHeight,
      behavior: command.smooth ? "smooth" : "instant",
    });
  } else if (command.type === "thumbnail") {
    const m = current.messages.find((m) => m.id === command.messageId);
    if (m)
      receive({
        type: "patch",
        session: current.session,
        messages: [
          {
            ...m,
            attachments: m.attachments.map((a) =>
              a.id === command.attachmentId
                ? { ...a, thumbnail: command.data }
                : a,
            ),
          },
        ],
      });
  }
}

engineReady
  .then(() => {
    flushSync(() =>
      createRoot(document.getElementById("root")).render(
        <MarkdownDelegateProvider
          openExternalLink={(uri) =>
            send({ type: "link", session: current.session, uri })
          }
        >
          <View />
        </MarkdownDelegateProvider>,
      ),
    );
    window.StroomMessageView = { receive };
    document.addEventListener("click", (event) => {
      const link = event.target.closest("a");
      if (!link) return;
      const uri = link.getAttribute("href");
      if (!uri || uri.startsWith("#")) return;
      const scheme = /^([a-z][a-z\d+.-]*):/i.exec(uri)?.[1].toLowerCase();
      if (scheme === "mailto") {
        event.preventDefault();
        send({ type: "link", session: current.session, uri });
      }
    });
    window.addEventListener("message", (event) => {
      if (event.source !== window.parent) return;
      const data = event.data;
      if (data?.channel && data.command) {
        channel = data.channel;
        receive(data.command);
      }
    });
    window.addEventListener("flutterInAppWebViewPlatformReady", () =>
      send({ type: "ready" }),
    );
    requestAnimationFrame(() => {
      send({ type: "ready" });
      window.parent.postMessage({ type: "stroomMessageReady" }, "*");
    });
  })
  .catch((error) => {
    document.getElementById("root").textContent =
      "消息界面无法初始化，请重新打开会话。";
    console.error(error);
  });
