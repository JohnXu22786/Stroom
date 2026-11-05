const { test } = require("node:test");
const assert = require("node:assert/strict");
const { JSDOM } = require("jsdom");

const renderer = import("./src/html-preview.js");

test("HTML fragments are wrapped once and keep scripts and external resources", async () => {
  const { buildHtmlPreviewDocument } = await renderer;
  const dom = new JSDOM("");
  const source = `<main><h1>Inline</h1></main>
<script>window.ran = true;</script>
<script src="https://cdn.example.test/widget.js"></script>
<img src="https://images.example.test/plot.png">`;
  const result = buildHtmlPreviewDocument(
    source,
    "fragment-token",
    dom.window.DOMParser,
  );
  const parsed = new dom.window.DOMParser().parseFromString(result, "text/html");
  assert.equal(parsed.querySelectorAll("body").length, 1);
  assert.equal(parsed.body.querySelector("main h1")?.textContent, "Inline");
  assert.equal(parsed.body.querySelectorAll("script").length, 2);
  assert.equal(
    parsed.body.querySelector('script[src^="https://cdn.example.test/"]') !== null,
    true,
  );
  assert.equal(parsed.body.querySelector('img[src^="https://images.example.test/"]') !== null, true);
  assert.match(parsed.head.innerHTML, /fragment-token/);
  dom.window.close();
});

test("complete HTML documents keep their head and body instead of nesting", async () => {
  const { buildHtmlPreviewDocument } = await renderer;
  const source = `<!doctype html><html lang="en"><head><title>Full page</title>
<script src="https://cdn.example.test/app.js"></script></head>
<body><main>Existing body</main></body></html>`;
  const dom = new JSDOM("");
  const result = buildHtmlPreviewDocument(
    source,
    "document-token",
    dom.window.DOMParser,
  );
  const parsed = new dom.window.DOMParser().parseFromString(result, "text/html");
  assert.equal(parsed.documentElement.lang, "en");
  assert.equal(parsed.querySelectorAll("head").length, 1);
  assert.equal(parsed.querySelectorAll("body").length, 1);
  assert.equal(parsed.title, "Full page");
  assert.equal(parsed.body.querySelector("main")?.textContent, "Existing body");
  assert.equal(parsed.querySelector('script[src="https://cdn.example.test/app.js"]') !== null, true);
  assert.match(parsed.head.innerHTML, /document-token/);
  dom.window.close();
});

test("the injected monitor runs page scripts and reports the rendered height", async () => {
  const { buildHtmlPreviewDocument } = await renderer;
  const messages = [];
  const parserDom = new JSDOM("");
  const source =
    "<script>document.documentElement.dataset.previewRan = 'yes'</script>" +
    "<main>Content</main>";
  const document = buildHtmlPreviewDocument(
    source,
    "monitor-token",
    parserDom.window.DOMParser,
  );
  parserDom.window.close();
  let rootScrollHeight = 300;
  const dom = new JSDOM(document, {
    runScripts: "dangerously",
    pretendToBeVisual: true,
    beforeParse(window) {
      window.MutationObserver = undefined;
      Object.defineProperty(window, "innerHeight", {
        configurable: true,
        writable: true,
        value: 300,
      });
      Object.defineProperties(window.HTMLElement.prototype, {
        scrollHeight: {
          get() {
            return this.tagName === "HTML" ? rootScrollHeight : 40;
          },
        },
        offsetHeight: {
          get() {
            return this.tagName === "HTML" ? window.innerHeight : 40;
          },
        },
      });
      Object.defineProperty(window, "parent", {
        configurable: true,
        value: { postMessage: (message) => messages.push(message) },
      });
    },
  });
  await new Promise((resolve) => setTimeout(resolve, 40));
  assert.equal(dom.window.document.documentElement.dataset.previewRan, "yes");
  assert.ok(
    messages.some(
      (message) =>
        message.type === "stroom-html-preview" &&
        message.token === "monitor-token" &&
        message.kind === "height" &&
        message.height === 40 &&
        message.viewportHeight === 300,
    ),
    "short content should measure to its content height instead of the iframe viewport",
  );
  const heightReports = () =>
    messages.filter((message) => message.kind === "height").length;
  const initialHeightReports = heightReports();
  dom.window.dispatchEvent(new dom.window.Event("resize"));
  await new Promise((resolve) => setTimeout(resolve, 40));
  assert.equal(
    heightReports(),
    initialHeightReports,
    "remeasuring unchanged content should not report the same height again",
  );
  dom.window.innerHeight = 250;
  rootScrollHeight = 40;
  dom.window.dispatchEvent(new dom.window.Event("resize"));
  await new Promise((resolve) => setTimeout(resolve, 40));
  assert.ok(
    messages.some(
      (message) =>
        message.kind === "height" &&
        message.height === 40 &&
        message.viewportHeight === 250,
    ),
    "a changed iframe viewport should report even when its content height is unchanged",
  );
  const image = dom.window.document.createElement("img");
  dom.window.document.body.append(image);
  rootScrollHeight = 400;
  image.dispatchEvent(new dom.window.Event("load"));
  await new Promise((resolve) => setTimeout(resolve, 40));
  assert.ok(
    messages.some(
      (message) =>
        message.kind === "height" &&
        message.height === 400 &&
        message.viewportHeight === 250,
    ),
    "a resource that finishes after page load should trigger a new height measurement",
  );
  const dispatchTargetedError = (tagName) => {
    const event = new dom.window.Event("error");
    Object.defineProperty(event, "target", {
      configurable: true,
      value: dom.window.document.createElement(tagName),
    });
    dom.window.dispatchEvent(event);
  };
  dispatchTargetedError("IMG");
  assert.equal(
    messages.some((message) => message.kind === "error"),
    false,
    "a failed network image should not make a functioning page fall back to source",
  );
  dom.window.dispatchEvent(
    new dom.window.ErrorEvent("error", { message: "preview failed" }),
  );
  assert.ok(messages.some((message) => message.kind === "error"));
  dispatchTargetedError("SCRIPT");
  assert.equal(
    messages.filter((message) => message.kind === "error").length,
    2,
    "runtime exceptions and failed scripts should report execution errors",
  );
  dom.window.close();
});
