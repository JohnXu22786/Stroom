import { build } from "esbuild";
import { readFile, writeFile, mkdir, readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.dirname(fileURLToPath(import.meta.url));
const output = path.resolve(root, "../../assets/vendor/dsh_message_view");
// Pinned upstream package, MIT. Fail on upstream drift rather than silently
// dropping Stroom's fence controls or safe inline HTML extensions.
const dshAdaptation = {
  name: "stroom-dsh-adaptation",
  setup(builder) {
    builder.onLoad(
      { filter: /dsh-client-ui-primitives\/lib\/index\.js$/ },
      async ({ path: file }) => {
        let contents = await readFile(file, "utf8");
        function replaceOnce(from, to) {
          if (contents.split(from).length !== 2)
            throw new Error(`DSH adaptation anchor changed: ${from}`);
          contents = contents.replace(from, to);
        }
        // Rename the recovery helper and wrap it: source positions stay intact,
        // including positions used by DSH's incremental parser and React keys.
        replaceOnce(
          "function recoverLocalImages(",
          "function upstreamRecoverLocalImages(",
        );
        contents +=
          "\nfunction recoverLocalImages(root, text) { return normalizeInlineHtml(upstreamRecoverLocalImages(root, text)); }\n";
        replaceOnce(
          'case "html": return node.value;',
          'case "stroomUnderline": return jsx("u", {children: renderChildren(node.children, context)}, key);\n\t\tcase "html": return node.value;',
        );
        replaceOnce(
          "const regexEngine = createJavaScriptRegexEngine({\n\tforgiving: true,\n\tregexConstructor: (pattern) => defaultJavaScriptRegexConstructor(pattern, { lazyCompileLength: Number.POSITIVE_INFINITY })\n});",
          "const regexEngine = stroomRegexEngine;",
        );
        replaceOnce(
          "setTimeout(() => {\n\thighlighter();\n}, 0).unref?.();",
          "stroomEngineReady.then(highlighter);",
        );
        // Fence rendering stays in DSH's Markdown pipeline; this component
        // supplies Stroom's code/HTML/Mermaid operations around DSH CodeBlock.
        replaceOnce(
          "return jsx(CodeBlock, {\n\t\tcode: `${node.value}\\n`,",
          "return jsx(StroomCode, {\n\t\tsourceStart: node.position?.start.offset,\n\t\tsourceEnd: node.position?.end.offset,\n\t\tcode: `${node.value}\\n`,",
        );
        contents =
          `import {regexEngine as stroomRegexEngine, engineReady as stroomEngineReady} from ${JSON.stringify(path.join(root, "src/highlighter.js"))};\nimport {normalizeInlineHtml} from ${JSON.stringify(path.join(root, "src/markdown-adaptation.js"))};\nimport {StroomCode} from ${JSON.stringify(path.join(root, "src/code.jsx"))};\n` +
          contents;
        return { contents, loader: "js", resolveDir: path.dirname(file) };
      },
    );
  },
};
const result = await build({
  entryPoints: [path.join(root, "src/main.jsx")],
  bundle: true,
  write: false,
  outfile: "message.js",
  format: "iife",
  minify: true,
  target: ["es2020"],
  // macOS 11's WebKit has ES2020 syntax but lacks this ES2022 runtime API.
  banner: {
    js: "if (!Array.prototype.at) Object.defineProperty(Array.prototype, 'at', {configurable:true,writable:true,value:function(index){var length=this.length>>>0;var n=Math.trunc(Number(index)||0);var k=n<0?length+n:n;return k<0||k>=length?undefined:this[k];}}); if (!Object.hasOwn) Object.defineProperty(Object, 'hasOwn', {configurable:true,writable:true,value:function(value,key){return Object.prototype.hasOwnProperty.call(value,key);}});",
  },
  jsx: "automatic",
  define: { "process.env.NODE_ENV": '"production"' },
  loader: {
    ".module.css": "local-css",
    ".woff2": "dataurl",
    ".woff": "dataurl",
    ".ttf": "dataurl",
  },
  plugins: [dshAdaptation],
  legalComments: "inline",
  metafile: true,
});
const js = result.outputFiles
  .find((f) => f.path.endsWith(".js"))
  .text.replace(/<\/script/gi, "<\\/script");
const css = result.outputFiles.find((f) => f.path.endsWith(".css")).text;
await mkdir(output, { recursive: true });
await writeFile(
  path.join(output, "index.html"),
  `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=5"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'unsafe-inline'; img-src data: https: http:; font-src data:; connect-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'"><style>${css}</style></head><body><div id="root"></div><script>${js}</script></body></html>\n`,
);
const license = await readFile(
  path.join(root, "node_modules/@deepseek-ai/dsh-client-ui-primitives/LICENSE"),
  "utf8",
);
await writeFile(path.join(output, "DSH-LICENSE.txt"), license);
console.log(
  `Bundled DSH message view: ${(Buffer.byteLength(js + css) / 1048576).toFixed(1)} MiB`,
);

// Notices for the packages contributing code, styles or fonts to this bundle.
const packages = new Set(
  Object.keys(result.metafile.inputs).flatMap((file) => {
    const match = /node_modules\/((?:@[^/]+\/)?[^/]+)/.exec(file);
    return match ? [match[1]] : [];
  }),
);
const notices = [];
for (const name of [...packages].sort()) {
  const dir = path.join(root, "node_modules", name);
  const manifest = JSON.parse(
    await readFile(path.join(dir, "package.json"), "utf8"),
  );
  const files = (await readdir(dir)).filter((file) =>
    /^(licen[sc]e|copying|notice)([.-]|$)/i.test(file),
  );
  const texts = await Promise.all(
    files.map((file) => readFile(path.join(dir, file), "utf8").catch(() => "")),
  );
  notices.push(
    `${name}@${manifest.version} (${manifest.license || "see notice"})\n${texts.join("\n")}`,
  );
}
notices.push(await readFile(path.join(root, "KATEX-FONT-LICENSE.txt"), "utf8"));
notices.push(await readFile(path.join(root, "ONIGURUMA-NOTICES.txt"), "utf8"));
await writeFile(
  path.join(output, "THIRD-PARTY-NOTICES.txt"),
  notices.join("\n\n----------------------------------------\n\n") + "\n",
);
