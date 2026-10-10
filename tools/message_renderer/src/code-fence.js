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
  const quoteEnd = prefix.lastIndexOf(">") + 1;
  const quoteColumn = columns(prefix.slice(0, quoteEnd));
  const tail = prefix.slice(quoteEnd);
  const optionalSpace = /^[ \t]/.test(tail) ? 1 : 0;
  const indent = quotes
    ? columns(stripIndent(tail, optionalSpace, quoteColumn), quoteColumn + optionalSpace)
    : columns(prefix);
  const lines = text.slice(start, end).split("\n");
  for (let i = 1; i < lines.length; i++) {
    let line = lines[i];
    let column = 0;
    for (let q = 0; q < quotes; q++) {
      const quote = /^[ \t]*>/.exec(line);
      if (!quote) break;
      column += columns(quote[0], column);
      line = line.slice(quote[0].length);
      if (/^[ \t]/.test(line)) {
        line = stripIndent(line, 1, column);
        column++;
      }
    }
    lines[i] = stripIndent(line, indent, column);
  }
  const source = lines.join("\n");
  const opening = /^ {0,3}(`{3,}|~{3,})[^\n]*\n/.exec(source);
  if (!opening) return end < text.trimEnd().length;
  return new RegExp(
    "^ {0,3}" + opening[1][0] + "{" + opening[1].length + ",}[ \t]*$",
    "m",
  ).test(source.slice(opening[0].length));
}

function columns(text, column = 0) {
  const start = column;
  for (const unit of text) column += unit === "\t" ? 4 - column % 4 : 1;
  return column - start;
}

function stripIndent(line, width, column = 0) {
  let consumed = 0;
  let offset = 0;
  while (offset < line.length && consumed < width) {
    const unit = line[offset];
    if (unit !== " " && unit !== "\t") break;
    consumed += unit === "\t" ? 4 - (column + consumed) % 4 : 1;
    offset++;
  }
  return " ".repeat(Math.max(0, consumed - width)) + line.slice(offset);
}
