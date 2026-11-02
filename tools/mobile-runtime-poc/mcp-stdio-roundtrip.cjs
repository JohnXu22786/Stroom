const assert = require('node:assert/strict');
const { PassThrough } = require('node:stream');
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} = require('@modelcontextprotocol/sdk/types.js');
const { z } = require('zod');

async function main() {
  const stdin = new PassThrough();
  const stdout = new PassThrough();
  let output = '';
  stdout.setEncoding('utf8');
  stdout.on('data', (chunk) => { output += chunk; });

  const server = new Server(
    { name: 'stroom-node-mobile-poc', version: '0.1.0' },
    { capabilities: { tools: {} } },
  );
  const schema = z.object({ left: z.number(), right: z.number() });
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [{
      name: 'add',
      description: 'Add two values',
      inputSchema: {
        type: 'object',
        properties: { left: { type: 'number' }, right: { type: 'number' } },
        required: ['left', 'right'],
      },
    }],
  }));
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { left, right } = schema.parse(request.params.arguments);
    return { content: [{ type: 'text', text: String(left + right) }] };
  });

  const transport = new StdioServerTransport(stdin, stdout);
  await server.connect(transport);
  const waitFor = async (id) => {
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline) {
      const lines = output.split('\n');
      for (const line of lines) {
        if (!line.trim()) continue;
        const message = JSON.parse(line);
        if (message.id === id) return message;
      }
      await new Promise((resolve) => setTimeout(resolve, 10));
    }
    throw new Error(`Timed out waiting for MCP response ${id}; output=${output}`);
  };
  const send = (message) => stdin.write(`${JSON.stringify(message)}\n`);

  send({
    jsonrpc: '2.0', id: 0, method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'poc-client', version: '0.1.0' },
    },
  });
  const initialized = await waitFor(0);
  assert.equal(initialized.result.serverInfo.name, 'stroom-node-mobile-poc');
  send({ jsonrpc: '2.0', method: 'notifications/initialized' });

  send({ jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} });
  const listed = await waitFor(1);
  assert.equal(listed.result.tools[0].name, 'add');

  send({
    jsonrpc: '2.0', id: 2, method: 'tools/call',
    params: { name: 'add', arguments: { left: 20, right: 22 } },
  });
  const called = await waitFor(2);
  assert.equal(called.result.content[0].text, '42');

  await transport.close();
  console.log('MCP_STDIO_ROUNDTRIP_PASS initialize tools/list tools/call=42');
}

main().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
