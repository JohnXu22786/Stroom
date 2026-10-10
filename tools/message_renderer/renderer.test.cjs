const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { JSDOM } = require("jsdom");

const wait = () => new Promise((resolve) => setTimeout(resolve, 60));
async function view({ legacy = false } = {}) {
  const events = [];
  const dom = new JSDOM(
    readFileSync("../../assets/vendor/dsh_message_view/index.html", "utf8"),
    {
      runScripts: "dangerously",
      pretendToBeVisual: true,
      beforeParse(window) {
        if (legacy) {
          delete window.Array.prototype.at;
          delete window.Object.hasOwn;
          const NativeRegExp = window.RegExp;
          const oldConstructor = (args) => {
            if (String(args[1] || "").includes("d"))
              throw new SyntaxError("match indices unavailable");
          };
          window.RegExp = new Proxy(NativeRegExp, {
            construct(target, args) {
              oldConstructor(args);
              return Reflect.construct(target, args);
            },
            apply(target, receiver, args) {
              oldConstructor(args);
              return Reflect.apply(target, receiver, args);
            },
          });
        }
        window.SVGElement.prototype.getBBox = () => ({
          x: 0,
          y: 0,
          width: 80,
          height: 24,
        });
        window.SVGElement.prototype.getComputedTextLength = () => 80;
        window.flutter_inappwebview = {
          callHandler: (name, event) => {
            events.push(event);
            return Promise.resolve();
          },
        };
        window.matchMedia = () => ({
          matches: false,
          addEventListener() {},
          removeEventListener() {},
        });
        window.ResizeObserver = class {
          observe() {}
          disconnect() {}
        };
        window.IntersectionObserver = class {
          constructor(callback) {
            this.callback = callback;
          }
          observe(target) {
            this.callback([{ target, isIntersecting: true }]);
          }
          unobserve() {}
          disconnect() {}
        };
        window.HTMLElement.prototype.scrollIntoView = function () {
          this.dataset.scrolled = "yes";
        };
        window.HTMLElement.prototype.scrollTo = function (options) {
          this.scrollTop = options.top;
        };
      },
    },
  );
  for (
    let attempt = 0;
    attempt < 50 && !dom.window.document.getElementById("transcript");
    attempt++
  )
    await wait();
  assert.ok(
    dom.window.document.getElementById("transcript"),
    "renderer became ready",
  );
  return {
    dom,
    events,
    receive: (command) => dom.window.StroomMessageView.receive(command),
  };
}
function snapshot(session, messages, extra = {}) {
  return {
    type: "snapshot",
    session,
    messages,
    theme: { dark: false, fontSize: 16 },
    hasOlder: false,
    ...extra,
  };
}
const message = (id, blocks, extra = {}) => ({
  id,
  role: "assistant",
  blocks,
  actions: ["copy", "save", "retry", "raw", "json", "delete"],
  ...extra,
});

test("DSH Markdown preserves safe extensions, tools and incomplete streaming fences", async () => {
  const v = await view();
  v.receive(
    snapshot("a", [
      message(
        "m",
        [
          {
            type: "text",
            text: "前<br>后 <u>**下划线**</u>\n\n<script>window.bad=1</script>\n\n$\\ce{H2O}$",
          },
          { type: "reasoning", text: "想法", isComplete: true },
          {
            type: "tool_call",
            id: "t",
            name: "read",
            arguments: { file: "a" },
            status: "completed",
            result: "输出",
          },
          { type: "text", text: "```html\n<h1>标题</h1>", streaming: true },
        ],
        { streaming: true },
      ),
    ]),
  );
  await wait();
  const doc = v.dom.window.document;
  assert.equal(doc.querySelector("u strong")?.textContent, "下划线");
  assert.ok(doc.querySelector("br"));
  assert.equal(v.dom.window.bad, undefined);
  assert.deepEqual(
    [...doc.querySelectorAll("[data-block-type]")].map(
      (n) => n.dataset.blockType,
    ),
    ["text", "reasoning", "tool_call", "text"],
  );
  assert.equal(doc.querySelector('[data-action="html"]')?.disabled, true);
  v.receive(
    snapshot("a", [
      message("m", [
        { type: "text", text: "```html\n<h1>标题</h1>\n```\n\n$\\ce{H2O}$" },
      ]),
    ]),
  );
  await wait();
  assert.ok(doc.querySelector(".katex"));
  assert.equal(doc.querySelector('[data-action="html"]')?.disabled, false);
  v.dom.window.close();
});

test("Markdown links open supported schemes and preserve local anchors", async () => {
  const v = await view();
  v.receive(
    snapshot("links", [
      message("m", [
        {
          type: "text",
          text: "[web](https://example.com) [mail](mailto:a@example.com) [note](#footnote)",
        },
      ]),
    ]),
  );
  await wait();
  const doc = v.dom.window.document;
  const links = [...doc.querySelectorAll("a")];
  assert.equal(links.length, 2);

  const localAnchor = doc.createElement("a");
  localAnchor.href = "#footnote";
  localAnchor.textContent = "note";
  doc.querySelector("[data-message-id='m']").append(localAnchor);

  const anchorClick = new v.dom.window.MouseEvent("click", {
    bubbles: true,
    cancelable: true,
  });
  localAnchor.dispatchEvent(anchorClick);
  assert.equal(anchorClick.defaultPrevented, false);
  assert.deepEqual(v.events.filter((event) => event.type === "link"), []);

  const modifiedClick = new v.dom.window.MouseEvent("click", {
    bubbles: true,
    cancelable: true,
    ctrlKey: true,
  });
  links[0].dispatchEvent(modifiedClick);
  assert.equal(modifiedClick.defaultPrevented, false);
  assert.deepEqual(v.events.filter((event) => event.type === "link"), []);

  for (const link of links) {
    const click = new v.dom.window.MouseEvent("click", {
      bubbles: true,
      cancelable: true,
    });
    link.dispatchEvent(click);
    assert.equal(click.defaultPrevented, true);
  }
  assert.deepEqual(
    v.events.filter((event) => event.type === "link").map((event) => event.uri),
    [
      "https://example.com",
      "mailto:a@example.com",
    ],
  );
  v.dom.window.close();
});

test("session replacement invalidates old updates and actions contain stable targets", async () => {
  const v = await view();
  v.receive(snapshot("a", [message("old", [{ type: "text", text: "旧" }])]));
  await wait();
  v.receive(
    snapshot("b", [
      message("new", [{ type: "reasoning", text: "新推理", isComplete: true }]),
    ]),
  );
  await wait();
  v.receive({
    type: "patch",
    session: "a",
    messages: [message("old", [{ type: "text", text: "迟到" }])],
  });
  await wait();
  const doc = v.dom.window.document;
  assert.equal(doc.querySelector('[data-message-id="old"]'), null);
  doc.querySelector('[data-action="reasoning"]').click();
  doc.querySelector('[data-action="copy"]').click();
  assert.deepEqual(JSON.parse(JSON.stringify(v.events.slice(-2))), [
    {
      type: "action",
      session: "b",
      messageId: "new",
      action: "reasoning",
      blockIndex: 0,
    },
    { type: "action", session: "b", messageId: "new", action: "copy" },
  ]);
  assert.equal(
    doc.querySelector('[data-action="like"], [data-action="dislike"]'),
    null,
  );
  v.dom.window.close();
});

test("prepend retains messages and search selects the requested occurrence", async () => {
  const v = await view();
  v.receive(
    snapshot("a", [message("m", [{ type: "text", text: "你好世界，你好" }])]),
  );
  await wait();
  v.receive({
    type: "patch",
    session: "a",
    messages: [message("older", [{ type: "text", text: "过去" }])],
    order: ["older", "m"],
  });
  await wait();
  v.receive({
    type: "search",
    session: "a",
    query: "你好",
    messageId: "m",
    occurrence: 1,
  });
  await wait();
  const doc = v.dom.window.document;
  assert.deepEqual(
    [...doc.querySelectorAll("[data-message-id]")].map(
      (n) => n.dataset.messageId,
    ),
    ["older", "m"],
  );
  assert.equal(doc.querySelector("mark.current")?.textContent, "你好");
  assert.equal(doc.querySelector("mark.current")?.dataset.scrolled, "yes");
  v.receive({
    type: "patch",
    session: "a",
    messages: [message("m", [{ type: "text", text: "你好新内容，你好" }])],
  });
  await wait();
  assert.equal(
    doc.querySelector('[data-message-id="m"] [data-search-text]').textContent,
    "你好新内容，你好",
  );
  assert.equal(doc.querySelector("mark.current")?.textContent, "你好");
  v.dom.window.close();
});

test("older WebKit without Array.at still renders assistant Markdown", async () => {
  const v = await view({ legacy: true });
  v.receive(
    snapshot("a", [
      message("m", [{ type: "text", text: "hello<br><u>world</u>" }]),
    ]),
  );
  await wait();
  assert.equal(v.dom.window.document.querySelector("u")?.textContent, "world");
  v.dom.window.close();
});

test("code wrapping changes the inherited DSH line style", async () => {
  const v = await view();
  try {
    v.receive(
      snapshot("a", [
        message("m", [
          { type: "text", text: "```js\nconst text = 'a long line';\n```" },
        ]),
      ]),
    );
    await wait();
    const doc = v.dom.window.document,
      card = doc.querySelector(".code-card");
    assert.ok(card?.querySelector("pre"));
    assert.equal(
      v.dom.window
        .getComputedStyle(card)
        .getPropertyValue("--dsl-code-block-line-white-space"),
      "pre",
    );
    card.querySelector('[aria-label="自动换行"]').click();
    await wait();
    assert.equal(
      v.dom.window
        .getComputedStyle(card)
        .getPropertyValue("--dsl-code-block-line-white-space"),
      "pre-wrap",
    );
    assert.equal(
      card
        .querySelector('[aria-label="自动换行"]')
        .getAttribute("aria-pressed"),
      "true",
    );
  } finally {
    v.dom.window.close();
  }
});

test("legacy WebKit highlights code and provides Mermaid's missing API", async () => {
  const v = await view({ legacy: true });
  try {
    v.receive(
      snapshot("a", [
        message("m", [
          { type: "text", text: "```js\nconst answer = 42;\n```" },
        ]),
      ]),
    );
    await wait();
    const doc = v.dom.window.document;
    const tokens = doc.querySelectorAll(
      '.code-card pre span[style*="--shiki-"]',
    );
    assert.ok(
      tokens.length > 1,
      "JavaScript grammar emits colored tokens without RegExp match indices",
    );
    assert.equal(v.dom.window.Object.hasOwn({ value: 1 }, "value"), true);
    assert.equal(
      v.dom.window.Object.hasOwn(Object.create({ value: 1 }), "value"),
      false,
    );
  } finally {
    v.dom.window.close();
  }
});

test("stream following resumes at bottom and pauses when reading earlier text", async () => {
  const v = await view();
  try {
    const e = v.dom.window.document.getElementById("transcript");
    let top = 0,
      extent = 40;
    Object.defineProperties(e, {
      clientHeight: { get: () => 100 },
      scrollHeight: { get: () => extent },
      scrollTop: {
        get: () => top,
        set: (value) => {
          top = Math.max(0, Math.min(value, Math.max(0, extent - 100)));
        },
      },
    });
    v.receive(snapshot("a", [message("m", [{ type: "text", text: "short" }])]));
    await wait();
    extent = 240;
    v.receive({
      type: "patch",
      session: "a",
      messages: [message("m", [{ type: "text", text: "long" }])],
    });
    await wait();
    assert.equal(top, 140, "initial short conversation follows growth");
    e.dispatchEvent(
      new v.dom.window.WheelEvent("wheel", { deltaY: -60, bubbles: true }),
    );
    e.scrollTop = 40;
    e.dispatchEvent(new v.dom.window.Event("scroll"));
    await wait();
    extent = 340;
    v.receive({
      type: "patch",
      session: "a",
      messages: [message("m", [{ type: "text", text: "longer" }])],
    });
    await wait();
    assert.equal(top, 40, "upward reading retains position");
    e.scrollTop = 240;
    e.dispatchEvent(new v.dom.window.Event("scroll"));
    await wait();
    extent = 440;
    v.receive({
      type: "patch",
      session: "a",
      messages: [message("m", [{ type: "text", text: "latest" }])],
    });
    await wait();
    assert.equal(top, 340, "manual return to bottom resumes following");
    v.receive({
      type: "search",
      session: "a",
      query: "latest",
      messageId: "m",
      occurrence: 0,
    });
    await wait();
    e.dispatchEvent(new v.dom.window.Event("scroll"));
    await wait();
    extent = 540;
    v.receive({
      type: "patch",
      session: "a",
      messages: [message("m", [{ type: "text", text: "latest addition" }])],
    });
    await wait();
    assert.equal(top, 340, "search location does not resume following");
  } finally {
    v.dom.window.close();
  }
});

test("empty switch snapshot positions first loaded history at the last user", async () => {
  const v = await view();
  try {
    const e = v.dom.window.document.getElementById("transcript");
    let top = 0,
      extent = 0;
    Object.defineProperties(e, {
      clientHeight: { get: () => 100 },
      scrollHeight: { get: () => extent },
      scrollTop: {
        get: () => top,
        set: (x) => {
          top = Math.max(0, Math.min(x, Math.max(0, extent - 100)));
        },
      },
    });
    Object.defineProperty(v.dom.window.HTMLElement.prototype, "offsetTop", {
      configurable: true,
      get() {
        return this.classList.contains("user") ? 120 : 0;
      },
    });
    v.receive(
      snapshot("a", [message("stream", [], { streaming: true })], {
        historyLoaded: false,
      }),
    );
    await wait();
    extent = 500;
    v.receive({
      type: "patch",
      session: "a",
      historyLoaded: true,
      messages: [
        message("u", [], { role: "user" }),
        message("m", [{ type: "text", text: "long reply" }]),
      ],
    });
    await wait();
    assert.equal(
      top,
      120,
      "loading completes before initial last-user positioning",
    );
    extent = 600;
    v.receive({
      type: "patch",
      session: "a",
      messages: [message("m", [{ type: "text", text: "longer reply" }])],
    });
    await wait();
    assert.equal(top, 120, "reading initial reply does not jump to bottom");
  } finally {
    v.dom.window.close();
  }
});

test("search preserves paragraph and message-block boundaries and joins inline text", async () => {
  const v = await view();
  try {
    v.receive(
      snapshot("a", [
        message("m", [
          { type: "text", text: "foo\n\nbar\n\nfo**ob**ar" },
          { type: "text", text: "foo" },
          { type: "text", text: "bar" },
        ]),
      ]),
    );
    await wait();
    v.receive({ type: "search", session: "a", query: "foobar" });
    await wait();
    const results = v.events.filter((e) => e.type === "searchResults").at(-1);
    assert.deepEqual(JSON.parse(JSON.stringify(results.matches)), [
      { messageId: "m", occurrence: 0 },
    ]);
    assert.equal(
      [...v.dom.window.document.querySelectorAll("mark")]
        .map((n) => n.textContent)
        .join(""),
      "foobar",
    );
  } finally {
    v.dom.window.close();
  }
});

test("search highlights original offsets after Unicode lowercase expansion", async () => {
  const v = await view();
  try {
    v.receive(
      snapshot("a", [
        message("unicode", [{ type: "text", text: "İfoo" }]),
      ]),
    );
    await wait();
    v.receive({ type: "search", session: "a", query: "foo" });
    await wait();

    assert.equal(
      v.dom.window.document.querySelector("mark")?.textContent,
      "foo",
    );
  } finally {
    v.dom.window.close();
  }
});

test("preview readiness follows each fence, accepting case variants and settled tails", async () => {
  const v = await view();
  try {
    const update = (text, streaming) =>
      v.receive(
        snapshot("a", [
          message("m", [{ type: "text", text, streaming }], { streaming }),
        ]),
      );
    update("```HTML\n<h1>closed</h1>\n```\t\n\nmore prose", true);
    await wait();
    let button = v.dom.window.document.querySelector('[data-action="html"]');
    assert.ok(button, "uppercase fence offers HTML preview");
    assert.equal(
      button.disabled,
      false,
      "closed fence ready while prose streams",
    );
    button.click();
    assert.equal(v.events.at(-1).action, "html");
    update("> ```HTML\n> <h1>quoted</h1>\n> ```\n\nmore", true);
    await wait();
    assert.equal(
      v.dom.window.document.querySelector('[data-action="html"]').disabled,
      false,
      "quoted closed fence ready",
    );
    update("123. > ```HTML\n     > <h1>listed</h1>\n     > ```\n\nmore", true);
    await wait();
    assert.equal(
      v.dom.window.document.querySelector('[data-action="html"]').disabled,
      false,
      "quoted list fence ready",
    );
    update("- ```html\n\t<p>x</p>\n\t```\n\nmore", true);
    await wait();
    assert.equal(
      v.dom.window.document.querySelector('[data-action="html"]').disabled,
      false,
      "tab-indented list fence ready",
    );
    update("```html\n<h1>tail</h1>", true);
    await wait();
    assert.equal(
      v.dom.window.document.querySelector('[data-action="html"]').disabled,
      true,
      "open streaming fence waits",
    );
    update("```html\n<h1>tail</h1>", false);
    await wait();
    assert.equal(
      v.dom.window.document.querySelector('[data-action="html"]').disabled,
      false,
      "settled open fence ready",
    );
  } finally {
    v.dom.window.close();
  }
});
