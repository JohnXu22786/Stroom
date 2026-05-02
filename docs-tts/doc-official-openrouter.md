\# Create speech



POST https://openrouter.ai/api/v1//audio/speech

Content-Type: application/json



Synthesizes audio from the input text



Reference: https://openrouter.ai/docs/api/api-reference/tts/create-audio-speech



\## OpenAPI Specification



```yaml

openapi: 3.1.0

info:

&#x20; title: OpenRouter API

&#x20; version: 1.0.0

paths:

&#x20; //audio/speech:

&#x20;   post:

&#x20;     operationId: create-audio-speech

&#x20;     summary: Create speech

&#x20;     description: Synthesizes audio from the input text

&#x20;     tags:

&#x20;       - subpackage\_tts

&#x20;     parameters:

&#x20;       - name: Authorization

&#x20;         in: header

&#x20;         description: API key as bearer token in Authorization header

&#x20;         required: true

&#x20;         schema:

&#x20;           type: string

&#x20;     responses:

&#x20;       '200':

&#x20;         description: Audio bytes stream

&#x20;         content:

&#x20;           application/octet-stream:

&#x20;             schema:

&#x20;               type: string

&#x20;               format: binary

&#x20;       '400':

&#x20;         description: Bad Request - Invalid request parameters or malformed input

&#x20;         content:

&#x20;           application/json:

&#x20;             schema:

&#x20;               $ref: '#/components/schemas/BadRequestResponse'

&#x20;       '401':

&#x20;         description: Unauthorized - Authentication required or invalid credentials

&#x20;         content:

&#x20;           application/json:

&#x20;             schema:

&#x20;               $ref: '#/components/schemas/UnauthorizedResponse'

&#x20;       '402':

&#x20;         description: Payment Required - Insufficient credits or quota to complete request

&#x20;         content:

&#x20;           application/json:

&#x20;             schema:

&#x20;               $ref: '#/components/schemas/PaymentRequiredResponse'

&#x20;       '404':

&#x20;         description: Not Found - Resource does not exist

&#x20;         content:

&#x20;           application/json:

&#x20;             schema:

&#x20;               $ref: '#/components/schemas/NotFoundResponse'

&#x20;       '429':

&#x20;         description: Too Many Requests - Rate limit exceeded

&#x20;         content:

&#x20;           application/json:

&#x20;             schema:

&#x20;               $ref: '#/components/schemas/TooManyRequestsResponse'

&#x20;       '500':

&#x20;         description: Internal Server Error - Unexpected server error

&#x20;         content:

&#x20;           application/json:

&#x20;             schema:

&#x20;               $ref: '#/components/schemas/InternalServerResponse'

&#x20;       '502':

&#x20;         description: Bad Gateway - Provider/upstream API failure

&#x20;         content:

&#x20;           application/json:

&#x20;             schema:

&#x20;               $ref: '#/components/schemas/BadGatewayResponse'

&#x20;       '503':

&#x20;         description: Service Unavailable - Service temporarily unavailable

&#x20;         content:

&#x20;           application/json:

&#x20;             schema:

&#x20;               $ref: '#/components/schemas/ServiceUnavailableResponse'

&#x20;     requestBody:

&#x20;       content:

&#x20;         application/json:

&#x20;           schema:

&#x20;             $ref: '#/components/schemas/SpeechRequest'

servers:

&#x20; - url: https://openrouter.ai/api/v1

components:

&#x20; schemas:

&#x20;   ProviderOptions:

&#x20;     type: object

&#x20;     properties:

&#x20;       01ai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       ai21:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       aion-labs:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       akashml:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       alibaba:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       amazon-bedrock:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       amazon-nova:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       ambient:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       anthropic:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       anyscale:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       arcee-ai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       atlas-cloud:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       atoma:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       avian:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       azure:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       baidu:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       baseten:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       black-forest-labs:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       byteplus:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       centml:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       cerebras:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       chutes:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       cirrascale:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       clarifai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       cloudflare:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       cohere:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       crofai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       crusoe:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       deepinfra:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       deepseek:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       dekallm:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       enfer:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       fake-provider:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       featherless:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       fireworks:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       friendli:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       gmicloud:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       google-ai-studio:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       google-vertex:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       gopomelo:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       groq:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       huggingface:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       hyperbolic:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       hyperbolic-quantized:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       inception:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       inceptron:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       inference-net:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       infermatic:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       inflection:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       inocloud:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       io-net:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       ionstream:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       klusterai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       lambda:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       lepton:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       liquid:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       lynn:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       lynn-private:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       mancer:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       mancer-old:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       mara:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       meta:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       minimax:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       mistral:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       modal:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       modelrun:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       modular:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       moonshotai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       morph:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       ncompass:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       nebius:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       nex-agi:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       nextbit:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       nineteen:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       novita:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       nvidia:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       octoai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       open-inference:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       openai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       parasail:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       perplexity:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       phala:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       poolside:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       recraft:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       recursal:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       reflection:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       reka:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       relace:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       replicate:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       sambanova:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       sambanova-cloaked:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       seed:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       sf-compute:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       siliconflow:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       sourceful:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       stealth:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       stepfun:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       streamlake:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       switchpoint:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       targon:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       together:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       together-lite:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       ubicloud:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       upstage:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       venice:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       wandb:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       xai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       xiaomi:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;       z-ai:

&#x20;         type: object

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     description: >-

&#x20;       Provider-specific options keyed by provider slug. The options for the

&#x20;       matched provider are spread into the upstream request body.

&#x20;     title: ProviderOptions

&#x20;   SpeechRequestProvider:

&#x20;     type: object

&#x20;     properties:

&#x20;       options:

&#x20;         $ref: '#/components/schemas/ProviderOptions'

&#x20;     description: Provider-specific passthrough configuration

&#x20;     title: SpeechRequestProvider

&#x20;   SpeechRequestResponseFormat:

&#x20;     type: string

&#x20;     enum:

&#x20;       - mp3

&#x20;       - pcm

&#x20;     default: pcm

&#x20;     description: Audio output format

&#x20;     title: SpeechRequestResponseFormat

&#x20;   SpeechRequest:

&#x20;     type: object

&#x20;     properties:

&#x20;       input:

&#x20;         type: string

&#x20;         description: Text to synthesize

&#x20;       model:

&#x20;         type: string

&#x20;         description: TTS model identifier

&#x20;       provider:

&#x20;         $ref: '#/components/schemas/SpeechRequestProvider'

&#x20;         description: Provider-specific passthrough configuration

&#x20;       response\_format:

&#x20;         $ref: '#/components/schemas/SpeechRequestResponseFormat'

&#x20;         description: Audio output format

&#x20;       speed:

&#x20;         type: number

&#x20;         format: double

&#x20;         description: >-

&#x20;           Playback speed multiplier. Only used by models that support it (e.g.

&#x20;           OpenAI TTS). Ignored by other providers.

&#x20;       voice:

&#x20;         type: string

&#x20;         description: Voice identifier (provider-specific).

&#x20;     required:

&#x20;       - input

&#x20;       - model

&#x20;       - voice

&#x20;     description: Text-to-speech request input

&#x20;     title: SpeechRequest

&#x20;   BadRequestResponseErrorData:

&#x20;     type: object

&#x20;     properties:

&#x20;       code:

&#x20;         type: integer

&#x20;       message:

&#x20;         type: string

&#x20;       metadata:

&#x20;         type:

&#x20;           - object

&#x20;           - 'null'

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     required:

&#x20;       - code

&#x20;       - message

&#x20;     description: Error data for BadRequestResponse

&#x20;     title: BadRequestResponseErrorData

&#x20;   BadRequestResponse:

&#x20;     type: object

&#x20;     properties:

&#x20;       error:

&#x20;         $ref: '#/components/schemas/BadRequestResponseErrorData'

&#x20;       user\_id:

&#x20;         type:

&#x20;           - string

&#x20;           - 'null'

&#x20;     required:

&#x20;       - error

&#x20;     description: Bad Request - Invalid request parameters or malformed input

&#x20;     title: BadRequestResponse

&#x20;   UnauthorizedResponseErrorData:

&#x20;     type: object

&#x20;     properties:

&#x20;       code:

&#x20;         type: integer

&#x20;       message:

&#x20;         type: string

&#x20;       metadata:

&#x20;         type:

&#x20;           - object

&#x20;           - 'null'

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     required:

&#x20;       - code

&#x20;       - message

&#x20;     description: Error data for UnauthorizedResponse

&#x20;     title: UnauthorizedResponseErrorData

&#x20;   UnauthorizedResponse:

&#x20;     type: object

&#x20;     properties:

&#x20;       error:

&#x20;         $ref: '#/components/schemas/UnauthorizedResponseErrorData'

&#x20;       user\_id:

&#x20;         type:

&#x20;           - string

&#x20;           - 'null'

&#x20;     required:

&#x20;       - error

&#x20;     description: Unauthorized - Authentication required or invalid credentials

&#x20;     title: UnauthorizedResponse

&#x20;   PaymentRequiredResponseErrorData:

&#x20;     type: object

&#x20;     properties:

&#x20;       code:

&#x20;         type: integer

&#x20;       message:

&#x20;         type: string

&#x20;       metadata:

&#x20;         type:

&#x20;           - object

&#x20;           - 'null'

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     required:

&#x20;       - code

&#x20;       - message

&#x20;     description: Error data for PaymentRequiredResponse

&#x20;     title: PaymentRequiredResponseErrorData

&#x20;   PaymentRequiredResponse:

&#x20;     type: object

&#x20;     properties:

&#x20;       error:

&#x20;         $ref: '#/components/schemas/PaymentRequiredResponseErrorData'

&#x20;       user\_id:

&#x20;         type:

&#x20;           - string

&#x20;           - 'null'

&#x20;     required:

&#x20;       - error

&#x20;     description: Payment Required - Insufficient credits or quota to complete request

&#x20;     title: PaymentRequiredResponse

&#x20;   NotFoundResponseErrorData:

&#x20;     type: object

&#x20;     properties:

&#x20;       code:

&#x20;         type: integer

&#x20;       message:

&#x20;         type: string

&#x20;       metadata:

&#x20;         type:

&#x20;           - object

&#x20;           - 'null'

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     required:

&#x20;       - code

&#x20;       - message

&#x20;     description: Error data for NotFoundResponse

&#x20;     title: NotFoundResponseErrorData

&#x20;   NotFoundResponse:

&#x20;     type: object

&#x20;     properties:

&#x20;       error:

&#x20;         $ref: '#/components/schemas/NotFoundResponseErrorData'

&#x20;       user\_id:

&#x20;         type:

&#x20;           - string

&#x20;           - 'null'

&#x20;     required:

&#x20;       - error

&#x20;     description: Not Found - Resource does not exist

&#x20;     title: NotFoundResponse

&#x20;   TooManyRequestsResponseErrorData:

&#x20;     type: object

&#x20;     properties:

&#x20;       code:

&#x20;         type: integer

&#x20;       message:

&#x20;         type: string

&#x20;       metadata:

&#x20;         type:

&#x20;           - object

&#x20;           - 'null'

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     required:

&#x20;       - code

&#x20;       - message

&#x20;     description: Error data for TooManyRequestsResponse

&#x20;     title: TooManyRequestsResponseErrorData

&#x20;   TooManyRequestsResponse:

&#x20;     type: object

&#x20;     properties:

&#x20;       error:

&#x20;         $ref: '#/components/schemas/TooManyRequestsResponseErrorData'

&#x20;       user\_id:

&#x20;         type:

&#x20;           - string

&#x20;           - 'null'

&#x20;     required:

&#x20;       - error

&#x20;     description: Too Many Requests - Rate limit exceeded

&#x20;     title: TooManyRequestsResponse

&#x20;   InternalServerResponseErrorData:

&#x20;     type: object

&#x20;     properties:

&#x20;       code:

&#x20;         type: integer

&#x20;       message:

&#x20;         type: string

&#x20;       metadata:

&#x20;         type:

&#x20;           - object

&#x20;           - 'null'

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     required:

&#x20;       - code

&#x20;       - message

&#x20;     description: Error data for InternalServerResponse

&#x20;     title: InternalServerResponseErrorData

&#x20;   InternalServerResponse:

&#x20;     type: object

&#x20;     properties:

&#x20;       error:

&#x20;         $ref: '#/components/schemas/InternalServerResponseErrorData'

&#x20;       user\_id:

&#x20;         type:

&#x20;           - string

&#x20;           - 'null'

&#x20;     required:

&#x20;       - error

&#x20;     description: Internal Server Error - Unexpected server error

&#x20;     title: InternalServerResponse

&#x20;   BadGatewayResponseErrorData:

&#x20;     type: object

&#x20;     properties:

&#x20;       code:

&#x20;         type: integer

&#x20;       message:

&#x20;         type: string

&#x20;       metadata:

&#x20;         type:

&#x20;           - object

&#x20;           - 'null'

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     required:

&#x20;       - code

&#x20;       - message

&#x20;     description: Error data for BadGatewayResponse

&#x20;     title: BadGatewayResponseErrorData

&#x20;   BadGatewayResponse:

&#x20;     type: object

&#x20;     properties:

&#x20;       error:

&#x20;         $ref: '#/components/schemas/BadGatewayResponseErrorData'

&#x20;       user\_id:

&#x20;         type:

&#x20;           - string

&#x20;           - 'null'

&#x20;     required:

&#x20;       - error

&#x20;     description: Bad Gateway - Provider/upstream API failure

&#x20;     title: BadGatewayResponse

&#x20;   ServiceUnavailableResponseErrorData:

&#x20;     type: object

&#x20;     properties:

&#x20;       code:

&#x20;         type: integer

&#x20;       message:

&#x20;         type: string

&#x20;       metadata:

&#x20;         type:

&#x20;           - object

&#x20;           - 'null'

&#x20;         additionalProperties:

&#x20;           description: Any type

&#x20;     required:

&#x20;       - code

&#x20;       - message

&#x20;     description: Error data for ServiceUnavailableResponse

&#x20;     title: ServiceUnavailableResponseErrorData

&#x20;   ServiceUnavailableResponse:

&#x20;     type: object

&#x20;     properties:

&#x20;       error:

&#x20;         $ref: '#/components/schemas/ServiceUnavailableResponseErrorData'

&#x20;       user\_id:

&#x20;         type:

&#x20;           - string

&#x20;           - 'null'

&#x20;     required:

&#x20;       - error

&#x20;     description: Service Unavailable - Service temporarily unavailable

&#x20;     title: ServiceUnavailableResponse

&#x20; securitySchemes:

&#x20;   apiKey:

&#x20;     type: http

&#x20;     scheme: bearer

&#x20;     description: API key as bearer token in Authorization header



```



\## SDK Code Examples



```python

import requests



url = "https://openrouter.ai/api/v1//audio/speech"



payload = {

&#x20;   "input": "Hello world",

&#x20;   "model": "elevenlabs/eleven-turbo-v2",

&#x20;   "voice": "alloy",

&#x20;   "response\_format": "pcm",

&#x20;   "speed": 1

}

headers = {

&#x20;   "Authorization": "Bearer <token>",

&#x20;   "Content-Type": "application/json"

}



response = requests.post(url, json=payload, headers=headers)



print(response.json())

```



```javascript

const url = 'https://openrouter.ai/api/v1//audio/speech';

const options = {

&#x20; method: 'POST',

&#x20; headers: {Authorization: 'Bearer <token>', 'Content-Type': 'application/json'},

&#x20; body: '{"input":"Hello world","model":"elevenlabs/eleven-turbo-v2","voice":"alloy","response\_format":"pcm","speed":1}'

};



try {

&#x20; const response = await fetch(url, options);

&#x20; const data = await response.json();

&#x20; console.log(data);

} catch (error) {

&#x20; console.error(error);

}

```



```go

package main



import (

&#x09;"fmt"

&#x09;"strings"

&#x09;"net/http"

&#x09;"io"

)



func main() {



&#x09;url := "https://openrouter.ai/api/v1//audio/speech"



&#x09;payload := strings.NewReader("{\\n  \\"input\\": \\"Hello world\\",\\n  \\"model\\": \\"elevenlabs/eleven-turbo-v2\\",\\n  \\"voice\\": \\"alloy\\",\\n  \\"response\_format\\": \\"pcm\\",\\n  \\"speed\\": 1\\n}")



&#x09;req, \_ := http.NewRequest("POST", url, payload)



&#x09;req.Header.Add("Authorization", "Bearer <token>")

&#x09;req.Header.Add("Content-Type", "application/json")



&#x09;res, \_ := http.DefaultClient.Do(req)



&#x09;defer res.Body.Close()

&#x09;body, \_ := io.ReadAll(res.Body)



&#x09;fmt.Println(res)

&#x09;fmt.Println(string(body))



}

```



```ruby

require 'uri'

require 'net/http'



url = URI("https://openrouter.ai/api/v1//audio/speech")



http = Net::HTTP.new(url.host, url.port)

http.use\_ssl = true



request = Net::HTTP::Post.new(url)

request\["Authorization"] = 'Bearer <token>'

request\["Content-Type"] = 'application/json'

request.body = "{\\n  \\"input\\": \\"Hello world\\",\\n  \\"model\\": \\"elevenlabs/eleven-turbo-v2\\",\\n  \\"voice\\": \\"alloy\\",\\n  \\"response\_format\\": \\"pcm\\",\\n  \\"speed\\": 1\\n}"



response = http.request(request)

puts response.read\_body

```



```java

import com.mashape.unirest.http.HttpResponse;

import com.mashape.unirest.http.Unirest;



HttpResponse<String> response = Unirest.post("https://openrouter.ai/api/v1//audio/speech")

&#x20; .header("Authorization", "Bearer <token>")

&#x20; .header("Content-Type", "application/json")

&#x20; .body("{\\n  \\"input\\": \\"Hello world\\",\\n  \\"model\\": \\"elevenlabs/eleven-turbo-v2\\",\\n  \\"voice\\": \\"alloy\\",\\n  \\"response\_format\\": \\"pcm\\",\\n  \\"speed\\": 1\\n}")

&#x20; .asString();

```



```php

<?php

require\_once('vendor/autoload.php');



$client = new \\GuzzleHttp\\Client();



$response = $client->request('POST', 'https://openrouter.ai/api/v1//audio/speech', \[

&#x20; 'body' => '{

&#x20; "input": "Hello world",

&#x20; "model": "elevenlabs/eleven-turbo-v2",

&#x20; "voice": "alloy",

&#x20; "response\_format": "pcm",

&#x20; "speed": 1

}',

&#x20; 'headers' => \[

&#x20;   'Authorization' => 'Bearer <token>',

&#x20;   'Content-Type' => 'application/json',

&#x20; ],

]);



echo $response->getBody();

```



```csharp

using RestSharp;



var client = new RestClient("https://openrouter.ai/api/v1//audio/speech");

var request = new RestRequest(Method.POST);

request.AddHeader("Authorization", "Bearer <token>");

request.AddHeader("Content-Type", "application/json");

request.AddParameter("application/json", "{\\n  \\"input\\": \\"Hello world\\",\\n  \\"model\\": \\"elevenlabs/eleven-turbo-v2\\",\\n  \\"voice\\": \\"alloy\\",\\n  \\"response\_format\\": \\"pcm\\",\\n  \\"speed\\": 1\\n}", ParameterType.RequestBody);

IRestResponse response = client.Execute(request);

```



```swift

import Foundation



let headers = \[

&#x20; "Authorization": "Bearer <token>",

&#x20; "Content-Type": "application/json"

]

let parameters = \[

&#x20; "input": "Hello world",

&#x20; "model": "elevenlabs/eleven-turbo-v2",

&#x20; "voice": "alloy",

&#x20; "response\_format": "pcm",

&#x20; "speed": 1

] as \[String : Any]



let postData = JSONSerialization.data(withJSONObject: parameters, options: \[])



let request = NSMutableURLRequest(url: NSURL(string: "https://openrouter.ai/api/v1//audio/speech")! as URL,

&#x20;                                       cachePolicy: .useProtocolCachePolicy,

&#x20;                                   timeoutInterval: 10.0)

request.httpMethod = "POST"

request.allHTTPHeaderFields = headers

request.httpBody = postData as Data



let session = URLSession.shared

let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in

&#x20; if (error != nil) {

&#x20;   print(error as Any)

&#x20; } else {

&#x20;   let httpResponse = response as? HTTPURLResponse

&#x20;   print(httpResponse)

&#x20; }

})



dataTask.resume()

```

