// DSH source offsets identify each fence in the Flutter-owned text block.
// Strip surrounding quote/list indentation like the native range resolver.
export function fenceComplete(text, start, end) {
  if (
    typeof text !== "string" ||
    !Number.isInteger(start) ||
    !Number.isInteger(end) ||
    start < 0 ||
    end <= start ||
    end > text.length
  )
    return false;
  const lineStart = start === 0 ? 0 : text.lastIndexOf("\n", start - 1) + 1;
  const prefix = text.slice(lineStart, start);
  const quotes = (prefix.match(/>/g) || []).length;
  const indent = prefix.replace(/ {0,3}> ?/g, "").length;
  const lines = text.slice(start, end).split("\n");
  for (let i = 1; i < lines.length; i++) {
    let line = lines[i];
    for (let q = 0; q < quotes; q++) line = line.replace(/^ {0,3}> ?/, "");
    if (indent && line.startsWith(" ".repeat(indent)))
      line = line.slice(indent);
    lines[i] = line;
  }
  const source = lines.join("\n");
  const opening = /^ {0,3}(`{3,}|~{3,})[^\n]*\n/.exec(source);
  if (!opening) return end < text.trimEnd().length;
  return new RegExp(
    "^ {0,3}" + opening[1][0] + "{" + opening[1].length + ",}[ \t]*$",
    "m",
  ).test(source.slice(opening[0].length));
}
