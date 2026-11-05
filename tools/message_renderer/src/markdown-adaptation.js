// Only <br> and paired <u> tags are allowed. Everything else stays text.
// Transform the AST rather than injecting model-authored HTML into the DOM.
export function normalizeInlineHtml(node) {
  if (!node.children) return node;
  const children = node.children.map(normalizeInlineHtml);
  const output = [];
  const stack = [output];
  for (let i = 0; i < children.length; i++) {
    const child = children[i];
    if (child.type === "html" && /^<br\s*\/?\s*>$/i.test(child.value)) {
      stack.at(-1).push({ ...child, type: "break" });
    } else if (
      child.type === "html" &&
      /^<u>$/i.test(child.value) &&
      children
        .slice(i + 1)
        .some((n) => n.type === "html" && /^<\/u>$/i.test(n.value))
    ) {
      const underline = {
        type: "stroomUnderline",
        children: [],
        position: child.position,
      };
      stack.at(-1).push(underline);
      stack.push(underline.children);
    } else if (
      child.type === "html" &&
      /^<\/u>$/i.test(child.value) &&
      stack.length > 1
    ) {
      stack.pop();
    } else {
      stack.at(-1).push(child);
    }
  }
  return { ...node, children: output };
}
