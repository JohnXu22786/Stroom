const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const vm = require("node:vm");

test("Web startup migration matches canonical ordering and retries malformed data", () => {
  let listener, result;
  const context = {
    self: {
      addEventListener: (name, fn) => (listener = fn),
      postMessage: (value) => (result = value),
    },
  };
  vm.runInNewContext(
    readFileSync("../../web/data_integrity_json_worker.js", "utf8"),
    context,
  );
  const messages = [
    {
      role: "assistant",
      content: "正文",
      reasoningContent: "推理",
      reasoningSections: [],
    },
    {
      role: "assistant",
      content: "结尾",
      reasoningSections: ["第一轮", "", "最终推理"],
      textSections: ["开头", "", "结尾"],
      toolCallRoundStarts: [0, 1],
      toolCalls: [
        {
          id: "a",
          name: "read",
          arguments: {},
          status: "completed",
          result: "a",
        },
        {
          id: "b",
          name: "search",
          arguments: {},
          status: "completed",
          result: "b",
        },
      ],
      blocks: [
        { type: "reasoning", text: "第一轮", isComplete: true },
        { type: "reasoning", text: "最终推理", isComplete: true },
      ],
    },
    {
      role: "assistant",
      isError: true,
      content: "错误: 中断\n\n---\n片段",
      blocks: [{ type: "text", text: "片段" }],
    },
    {
      role: "assistant",
      content: "遗漏的正文",
      reasoningSections: ["想法"],
      blocks: [{ type: "reasoning", text: "想法", isComplete: true }],
    },
  ];
  messages.push(
    {
      role: "assistant",
      content: "canonical",
      reasoningSections: "bad",
      blocks: [{ type: "text", text: "canonical" }],
    },
    {
      role: "assistant",
      content: "fallback",
      reasoningSections: ["idea", 7],
      textSections: false,
      toolCalls: "bad",
      toolCallRoundStarts: [0, "bad"],
    },
    { role: "assistant", content: "sibling" },
    {
      role: "assistant",
      content: "正文旁边的错误",
      blocks: [{ type: "error", message: "tool failed" }],
    },
  );
  listener({
    data: [
      "canonicalizeConversations",
      JSON.stringify([{ id: "c", messages }]),
    ],
  });
  assert.ok(result.startsWith("ok:"));
  const migrated = JSON.parse(result.slice(result.indexOf("\n") + 1))[0]
    .messages;
  assert.deepEqual(migrated[0].blocks, [
    { type: "reasoning", text: "推理", isComplete: true },
    { type: "text", text: "正文" },
  ]);
  assert.deepEqual(
    migrated[1].blocks.map((b) => b.type),
    [
      "reasoning",
      "text",
      "tool_call",
      "reasoning",
      "tool_call",
      "reasoning",
      "text",
    ],
  );
  assert.equal(migrated[1].blocks[3].text, "");
  assert.equal(migrated[3].blocks.at(-1).text, "遗漏的正文");
  assert.equal(migrated[2].blocks[0].text, "错误: 中断");
  assert.deepEqual(migrated[4], messages[4]);
  assert.deepEqual(migrated[5].blocks, [
    { type: "reasoning", text: "idea", isComplete: true },
    { type: "text", text: "fallback" },
  ]);
  assert.deepEqual(migrated[6].blocks, [{ type: "text", text: "sibling" }]);
  assert.deepEqual(migrated[7].blocks, [
    { type: "error", message: "tool failed" },
    { type: "text", text: "正文旁边的错误" },
  ]);
  const saved = result.slice(result.indexOf("\n") + 1);
  listener({ data: ["canonicalizeConversations", saved] });
  assert.equal(result.slice(result.indexOf("\n") + 1), saved);
  listener({ data: ["canonicalizeConversations", "{broken"] });
  assert.ok(result.startsWith("parse-error\n"));
});
