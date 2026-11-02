const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { transform } = require('sucrase');
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { InMemoryTransport } = require('@modelcontextprotocol/sdk/inMemory.js');
const { McpServer } = require('@modelcontextprotocol/sdk/server/mcp.js');
const { z } = require('zod');

async function main() {
  const fastUri = require('fast-uri');
  assert.equal(require('fast-uri/package.json').version, '3.1.0');
  assert.equal(typeof fastUri.parse, 'function');
  console.log('NPM_CI_OVERRIDE_PASS fast-uri@3.1.0');

  const tsFile = path.join(__dirname, 'math.ts');
  const tsSource = fs.readFileSync(tsFile, 'utf8');
  const compiled = transform(tsSource, { transforms: ['typescript', 'imports'], filePath: tsFile }).code;
  const mathModule = { exports: {} };
  vm.runInNewContext(compiled, { exports: mathModule.exports, module: mathModule });
  assert.equal(mathModule.exports.add(19, 23), 42);
  console.log('TS_TRANSPILE_EXECUTE_PASS value=42');

  const server = new McpServer({ name: 'stroom-mobile-poc', version: '0.1.0' });
  server.tool('add', 'Add two numbers', { left: z.number(), right: z.number() }, async ({ left, right }) => ({
    content: [{ type: 'text', text: String(left + right) }],
  }));
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: 'stroom-poc-client', version: '0.1.0' });
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  const list = await client.listTools();
  assert.equal(list.tools[0].name, 'add');
  const result = await client.callTool({ name: 'add', arguments: { left: 20, right: 22 } });
  assert.equal(result.content[0].text, '42');
  await client.close();
  await server.close();
  console.log('MCP_IN_MEMORY_INITIALIZE_LIST_CALL_PASS value=42');
  console.log('RESULT:PASS');
}

main().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
