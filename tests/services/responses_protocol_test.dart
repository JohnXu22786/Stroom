import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/services/chat_protocol.dart';

void main() {
  group('ResponsesProtocol', () {
    test(
      'maps instructions, image input, and tool call/result history',
      () async {
        final image = Attachment(
          fileName: 'cat.png',
          mimeType: 'image/png',
          fileType: 'image',
          hash: 'cat',
          storagePath: '/unused',
          fileSize: 3,
        )..base64Data = 'AQID';
        final request = await ResponsesProtocol().buildRequest(
          history: [
            ChatMessage(
              role: 'user',
              content: 'Describe this',
              attachments: [image],
            ),
            ChatMessage(
              role: 'assistant',
              content: 'Checking weather.',
              reasoningSections: ['Need weather data'],
              toolCalls: [
                ToolCallData(
                  id: 'call_1',
                  name: 'weather',
                  arguments: {'city': 'Oslo'},
                  status: ToolCallStatus.completed,
                  result: 'snow',
                ),
              ],
            ),
          ],
          assistantPrompt: 'Be concise',
          contextSummary: 'Earlier context',
        );

        expect(
          request.system,
          'Be concise\n\n以下是此前对话的摘要（对话曾被压缩）:\nEarlier context',
        );
        expect(request.messages[0], {
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': 'Describe this'},
            {'type': 'input_image', 'image_url': 'data:image/png;base64,AQID'},
          ],
        });
        expect(request.messages[1], {
          'type': 'reasoning',
          'summary': [
            {'type': 'summary_text', 'text': 'Need weather data'},
          ],
        });
        expect(request.messages[2], {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'input_text', 'text': 'Checking weather.'},
          ],
        });
        expect(request.messages[3], {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'weather',
          'arguments': '{"city":"Oslo"}',
        });
        expect(request.messages[4], {
          'type': 'function_call_output',
          'call_id': 'call_1',
          'output': 'snow',
        });
      },
    );

    test('replays assistant images as text instead of user-only input images',
        () async {
      final generatedImage = Attachment(
        fileName: 'generated.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'generated-image',
        storagePath: '/unused',
        fileSize: 3,
      )..base64Data = 'AQID';

      final request = await ResponsesProtocol().buildRequest(
        history: [
          ChatMessage(
            role: 'assistant',
            content: 'Here is the picture.',
            attachments: [generatedImage],
          ),
        ],
      );

      expect(request.messages.single, {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'input_text', 'text': 'Here is the picture.'},
          {'type': 'input_text', 'text': '[此前回复包含图片: generated.png]'},
        ],
      });
    });

    test('maps function tools and response tool-loop messages', () {
      const definition = ToolDefinition(
        name: 'lookup',
        description: 'Look it up',
        parameters: {'type': 'object'},
      );
      final protocol = ResponsesProtocol();
      expect(createChatProtocol('responses'), isA<ResponsesProtocol>());
      expect(protocol.toolDefsToJson([definition]), [
        {
          'type': 'function',
          'name': 'lookup',
          'description': 'Look it up',
          'parameters': {'type': 'object'},
        },
      ]);
      expect(
        protocol.buildAssistantChainMessage(
          content: 'I will check',
          toolCalls: const [
            NeutralToolCall(
              id: 'call_2',
              name: 'lookup',
              argumentsJson: '{"q":"x"}',
            ),
          ],
          roundReasoning: 'Searching',
        ),
        [
          {
            'type': 'reasoning',
            'summary': [
              {'type': 'summary_text', 'text': 'Searching'},
            ],
          },
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'input_text', 'text': 'I will check'},
            ],
          },
          {
            'type': 'function_call',
            'call_id': 'call_2',
            'name': 'lookup',
            'arguments': '{"q":"x"}',
          },
        ],
      );
      expect(
        protocol.buildToolResultMessages(const [
          ToolCallResult(toolCallId: 'call_2', result: 'found'),
        ]),
        [
          {
            'type': 'function_call_output',
            'call_id': 'call_2',
            'output': 'found',
          },
        ],
      );
    });

    test('replays parallel calls and outputs in each recorded round', () async {
      final request = await ResponsesProtocol().buildRequest(
        history: [
          ChatMessage(
            role: 'assistant',
            content: 'step one\nstep two\nfinal answer',
            contentFromTextSections: true,
            textSections: ['step one', 'step two', 'final answer'],
            reasoningSections: ['plan one', 'plan two'],
            toolCallRoundStarts: [0, 2],
            toolCalls: [
              ToolCallData(
                id: 'call-a',
                name: 'first',
                arguments: {},
                status: ToolCallStatus.completed,
                result: 'first result',
              ),
              ToolCallData(
                id: 'call-b',
                name: 'parallel',
                arguments: {},
                status: ToolCallStatus.completed,
                result: 'parallel result',
              ),
              ToolCallData(
                id: 'call-c',
                name: 'second round',
                arguments: {},
                status: ToolCallStatus.completed,
                result: 'second result',
              ),
            ],
          ),
        ],
      );

      expect(request.messages, [
        {
          'type': 'reasoning',
          'summary': [
            {'type': 'summary_text', 'text': 'plan one'},
          ],
        },
        {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'input_text', 'text': 'step one'},
          ],
        },
        {
          'type': 'function_call',
          'call_id': 'call-a',
          'name': 'first',
          'arguments': '{}'
        },
        {
          'type': 'function_call',
          'call_id': 'call-b',
          'name': 'parallel',
          'arguments': '{}'
        },
        {
          'type': 'function_call_output',
          'call_id': 'call-a',
          'output': 'first result'
        },
        {
          'type': 'function_call_output',
          'call_id': 'call-b',
          'output': 'parallel result'
        },
        {
          'type': 'reasoning',
          'summary': [
            {'type': 'summary_text', 'text': 'plan two'},
          ],
        },
        {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'input_text', 'text': 'step two'},
          ],
        },
        {
          'type': 'function_call',
          'call_id': 'call-c',
          'name': 'second round',
          'arguments': '{}',
        },
        {
          'type': 'function_call_output',
          'call_id': 'call-c',
          'output': 'second result',
        },
        {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'input_text', 'text': 'final answer'},
          ],
        },
      ]);
    });

    test(
      'maps audio and files, and makes unsupported video input explicit',
      () async {
        final audio = Attachment(
          fileName: 'voice.mp3',
          mimeType: 'audio/mpeg',
          fileType: 'audio',
          hash: 'audio',
          storagePath: '/unused',
          fileSize: 3,
        )..base64Data = 'AQID';
        final pdf = Attachment(
          fileName: 'notes.pdf',
          mimeType: 'application/pdf',
          fileType: 'document',
          hash: 'pdf',
          storagePath: '/unused',
          fileSize: 3,
        )..base64Data = 'AQID';
        final video = Attachment(
          fileName: 'clip.mp4',
          mimeType: 'video/mp4',
          fileType: 'video',
          hash: 'video',
          storagePath: '/unused',
          fileSize: 3,
        )..base64Data = 'AQID';

        final request = await ResponsesProtocol().buildRequest(
          history: [
            ChatMessage(
              role: 'user',
              content: '',
              attachments: [audio, pdf, video],
            ),
          ],
        );
        expect(request.messages.single['content'], [
          {
            'type': 'input_audio',
            'input_audio': {'data': 'AQID', 'format': 'mp3'},
          },
          {
            'type': 'input_file',
            'filename': 'notes.pdf',
            'file_data': 'data:application/pdf;base64,AQID',
          },
          {
            'type': 'input_text',
            'text': '[Responses 格式暂不支持视频输入，已跳过: clip.mp4]',
          },
        ]);
      },
    );

    test('makes unsupported audio input formats explicit', () async {
      final audio = Attachment(
        fileName: 'voice.ogg',
        mimeType: 'audio/ogg',
        fileType: 'audio',
        hash: 'audio-ogg',
        storagePath: '/unused',
        fileSize: 3,
      )..base64Data = 'AQID';

      final request = await ResponsesProtocol().buildRequest(
        history: [
          ChatMessage(
            role: 'user',
            content: '',
            attachments: [audio],
          ),
        ],
      );

      expect(request.messages.single['content'], [
        {
          'type': 'input_text',
          'text': '[Responses 格式暂不支持此音频格式，已跳过: voice.ogg]',
        },
      ]);
    });
  });
}
