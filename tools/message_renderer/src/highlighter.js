import { createOnigurumaEngine } from "shiki/engine/oniguruma";
import wasm from "shiki/wasm";

// DSH's synchronous scanner API backed by bundled Oniguruma, avoiding
// RegExp match indices unsupported by macOS 11 WebKit. Boot waits for WASM.
let engine;
export const engineReady = createOnigurumaEngine(wasm).then((value) => {
  engine = value;
});
export const regexEngine = {
  createScanner(patterns) {
    return engine.createScanner(patterns);
  },
  createString(value) {
    return engine.createString(value);
  },
};
