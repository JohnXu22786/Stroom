const { test } = require("node:test");
const assert = require("node:assert/strict");
const { build } = require("esbuild");
const { JSDOM } = require("jsdom");
const wait = () => new Promise((r) => setTimeout(r, 60));
test("Mermaid recovers after a failed render in the same code block", async () => {
  const result = await build({
    stdin: {
      contents: `import React from 'react'; import {createRoot} from 'react-dom/client'; import {StroomCode} from './src/code.jsx'; const root=createRoot(document.getElementById('root')); window.renderDiagram=code=>root.render(React.createElement(StroomCode,{code,lang:'mermaid'}));`,
      resolveDir: process.cwd(),
      loader: "jsx",
    },
    bundle: true,
    write: false,
    format: "iife",
    jsx: "automatic",
    define: { "process.env.NODE_ENV": '"production"' },
    plugins: [
      {
        name: "diagram-stub",
        setup(b) {
          b.onResolve(
            { filter: /^(mermaid|@deepseek-ai\/dsh-client-ui-primitives)$/ },
            (args) => ({ path: args.path, namespace: "stub" }),
          );
          b.onLoad({ filter: /.*/, namespace: "stub" }, (args) => ({
            contents:
              args.path === "mermaid"
                ? `export default {initialize(){},async render(id,code){if(code==='bad')throw Error('invalid');return {svg:'<svg><text>valid</text></svg>'};}};`
                : `export const CodeBlock=()=>null; export const IconCopyOutlineRegular=()=>null; export const IconDownloadOutlineRegular=()=>null; export const IconWrapLinesOutlineRegular=()=>null;`,
            loader: "js",
          }));
        },
      },
    ],
  });
  const dom = new JSDOM('<div id="root"></div>', {
    runScripts: "outside-only",
    pretendToBeVisual: true,
  });
  try {
    dom.window.eval(result.outputFiles[0].text);
    dom.window.renderDiagram("bad");
    await wait();
    assert.ok(dom.window.document.querySelector(".diagram p"));
    dom.window.renderDiagram("good");
    await wait();
    assert.ok(
      !dom.window.document.querySelector(".diagram p"),
      "error cleared after valid update",
    );
    assert.equal(
      dom.window.document.querySelector(".diagram svg text")?.textContent,
      "valid",
    );
  } finally {
    dom.window.close();
  }
});
