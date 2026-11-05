import structuredClone from "@ungap/structured-clone";

if (typeof globalThis.structuredClone !== "function") {
  Object.defineProperty(globalThis, "structuredClone", {
    configurable: true,
    writable: true,
    value: structuredClone,
  });
}
