> ## Documentation Index

> Fetch the complete documentation index at: https://docs.aihubmix.com/llms.txt

> Use this file to discover all available pages before exploring further.



\# TTS



> Convert text to natural speech using AI models, supporting various voice styles and output formats



\## Introduction



The Text-to-Speech (TTS) API is based on advanced generative AI models that can convert input text into realistic speech audio. It supports a variety of use cases:



\* Narrating written blog articles

\* Generating speech audio in multiple languages

\* Providing real-time audio output streams



\## Available Models



\### OpenAI Models



\* \[gpt-4o-audio-preview](https://aihubmix.com/model/gpt-4o-audio-preview) — OpenAI's latest audio generation model, supporting conversational audio generation

\* \[\*\*gpt-4o-mini-tts\*\*](https://aihubmix.com/model/gpt-4o-mini-tts) — The preferred model for smart real-time applications, supporting advanced voice control and allowing various voice characteristics to be controlled via prompts:

&#x20; 1. Accent

&#x20; 2. Emotional range

&#x20; 3. Intonation

&#x20; 4. Impressions/Style

&#x20; 5. Speed of speech

&#x20; 6. Tone

&#x20; 7. Whispering

\* \[\*\*tts-1-hd\*\*](https://aihubmix.com/model/tts-1-hd) — The previous generation TTS model with high-definition audio quality

\* \[\*\*tts-1\*\*](https://aihubmix.com/model/tts-1) — Standard TTS model, balancing quality and speed



\### Gemini Models



\* \[\*\*gemini-2.5-flash-preview-tts\*\*](https://aihubmix.com/model/gemini-2.5-flash-preview-tts) — Gemini fast TTS model, supporting single and multiple speaker audio generation

\* \[\*\*gemini-2.5-pro-preview-tts\*\*](https://aihubmix.com/model/gemini-2.5-pro-preview-tts) — Gemini professional TTS model, supporting single and multiple speaker audio generation



\*\*Performance Recommendations:\*\*



1\. For the fastest response time, it's recommended to use `wav` or `pcm` as the response format

2\. For high-quality audio, use `tts-1-hd`

3\. For faster generation speed, use `tts-1`

4\. For smart voice applications, `gpt-4o-mini-tts` is recommended

5\. For scenarios requiring multi-speaker dialogues, the Gemini TTS models are recommended



\## API Endpoint



\### Request URL



```shellscript theme={null}

POST https://aihubmix.com/v1/audio/speech

```



\### Request Headers



```shellscript theme={null}

Authorization: Bearer $AIHUBMIX\_API\_KEY

Content-Type: application/json

```



\### Request Parameters



\#### Standard TTS Parameters



The standard parameters applicable to the following TTS models: tts-1, tts-1-hd, gpt-4o-mini-tts, gemini-2.5-flash-preview-tts, and gemini-2.5-pro-preview-tts.



| Parameter        | Type   | Required | Description                                                                                                                                                                                                              |

| :--------------- | :----- | :------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |

| model            | string | Yes      | The model ID to be used. Optional values: `tts-1`, `tts-1-hd`, `gpt-4o-mini-tts`, `gemini-2.5-flash-preview-tts`, `gemini-2.5-pro-preview-tts`                                                                           |

| input            | string | Yes      | The text to generate audio from, with a maximum length of 4096 characters                                                                                                                                                |

| voice            | string | Yes      | The voice used for synthesis. See the voice list below.                                                                                                                                                                  |

| response\\\_format | string | No       | Audio output format. Supported audio formats include: `mp3`, `opus`, `aac`, `flac`, `wav`, `pcm`, default is `mp3`. `Note: Gemini models only support wav and pcm formats.`                                              |

| speed            | number | No       | The speed of the generated audio. Range from 0.25 to 4.0, default is 1.0. Note:  `gpt-4o-mini-tts` and `Gemini` models do not support this parameter, but speed can be controlled through natural language descriptions. |

| instructions     | string | No       | Voice generation instructions, which can specify voice style, intonation, and emotional characteristics in detail, applicable only for `gpt-4o-mini-tts` and `Gemini` models.                                            |



\#### gpt-4o-audio-preview Parameters



| Parameter  | Type   | Required | Description                                                       |

| :--------- | :----- | :------- | :---------------------------------------------------------------- |

| model      | string | Yes      | Set to `gpt-4o-audio-preview`                                     |

| modalities | array  | Yes      | Set to `\["text", "audio"]` to enable audio output                 |

| audio      | object | Yes      | Audio configuration object containing `voice` and `format` fields |

| messages   | array  | Yes      | Array of chat messages, similar to standard chat format           |



\## Voice List



\### OpenAI Voices



Supports the following voice options:



\* \*\*alloy\*\* - Neutral, balanced

\* \*\*ash\*\* - Clear, professional

\* \*\*ballad\*\* - Warm, narrative

\* \*\*coral\*\* - Friendly, approachable

\* \*\*echo\*\* - Clear, bright

\* \*\*fable\*\* - Expressive, dramatic

\* \*\*onyx\*\* - Deep, authoritative

\* \*\*nova\*\* - Lively, energetic

\* \*\*sage\*\* - Mature, knowledgeable

\* \*\*shimmer\*\* - Soft, soothing

\* \*\*verse\*\* - Clear, versatile

\* \*\*marin\*\* - Natural, friendly

\* \*\*cedar\*\* - Stable, reliable



\### Gemini Voices



Supports the following 30 voice options:



| Voice Name    | Style        | Voice Name        | Style           | Voice Name       | Style         |

| :------------ | :----------- | :---------------- | :-------------- | :--------------- | :------------ |

| \*\*Zephyr\*\*    | \*Bright\*     | \*\*Puck\*\*          | \*Upbeat\*        | \*\*Charon\*\*       | \*Informative\* |

| \*\*Kore\*\*      | \*Firm\*       | \*\*Fenrir\*\*        | \*Excitable\*     | \*\*Leda\*\*         | \*Youthful\*    |

| \*\*Orus\*\*      | \*Firm\*       | \*\*Aoede\*\*         | \*Breezy\*        | \*\*Callirrhoe\*\*   | \*Easy-going\*  |

| \*\*Autonoe\*\*   | \*Bright\*     | \*\*Enceladus\*\*     | \*Breathy\*       | \*\*Iapetus\*\*      | \*Clear\*       |

| \*\*Umbriel\*\*   | \*Easy-going\* | \*\*Algieba\*\*       | \*Smooth\*        | \*\*Despina\*\*      | \*Smooth\*      |

| \*\*Erinome\*\*   | \*Clear\*      | \*\*Algenib\*\*       | \*Gravelly\*      | \*\*Rasalgethi\*\*   | \*Informative\* |

| \*\*Laomedeia\*\* | \*Upbeat\*     | \*\*Achernar\*\*      | \*Soft\*          | \*\*Alnilam\*\*      | \*Firm\*        |

| \*\*Schedar\*\*   | \*Even\*       | \*\*Gacrux\*\*        | \*Mature\*        | \*\*Pulcherrima\*\*  | \*Forward\*     |

| \*\*Achird\*\*    | \*Friendly\*   | \*\*Zubenelgenubi\*\* | \*Casual\*        | \*\*Vindemiatrix\*\* | \*Gentle\*      |

| \*\*Sadachbia\*\* | \*Lively\*     | \*\*Sadaltager\*\*    | \*Knowledgeable\* | \*\*Sulafat\*\*      | \*Warm\*        |



\### Voice Mapping



When using Gemini models, if an OpenAI voice name is provided, the system will automatically map it to the corresponding Gemini voice:



| OpenAI Voice | Gemini Voice | OpenAI Voice | Gemini Voice |

| :----------- | :----------- | :----------- | :----------- |

| alloy        | Kore         | ash          | Fenrir       |

| ballad       | Aoede        | coral        | Leda         |

| echo         | Puck         | fable        | Zephyr       |

| onyx         | Charon       | nova         | Orus         |

| sage         | Algieba      | shimmer      | Callirrhoe   |

| verse        | Enceladus    | marin        | Despina      |

| cedar        | Iapetus      |              |              |



\## Usage Examples



\### Standard TTS Model (OpenAI)



```curl theme={null}

curl https://aihubmix.com/v1/audio/speech \\

&#x20; -H "Authorization: Bearer $AIHUBMIX\_API\_KEY" \\

&#x20; -H "Content-Type: application/json" \\

&#x20; -d '{

&#x20;   "model": "tts-1",

&#x20;   "input": "The quick brown fox jumped over the lazy dog.",

&#x20;   "voice": "alloy"

&#x20; }' \\

&#x20; --output speech.mp3

```



\### Gemini TTS Model (Single Speaker)



```curl theme={null}

curl https://aihubmix.com/v1/audio/speech \\

&#x20; -H "Authorization: Bearer $AIHUBMIX\_API\_KEY" \\

&#x20; -H "Content-Type: application/json" \\

&#x20; -d '{

&#x20;   "model": "gemini-2.5-flash-preview-tts",

&#x20;   "input": "Say cheerfully: Have a wonderful day!",

&#x20;   "voice": "Kore",

&#x20;   "response\_format": "wav"

&#x20; }' \\

&#x20; --output speech.wav

```



\### Gemini TTS Model (Multi-Speaker - Controlled by Prompts)



```curl theme={null}

curl https://aihubmix.com/v1/audio/speech \\

&#x20; -H "Authorization: Bearer $AIHUBMIX\_API\_KEY" \\

&#x20; -H "Content-Type: application/json" \\

&#x20; -d '{

&#x20;   "model": "gemini-2.5-flash-preview-tts",

&#x20;   "input": "TTS the following conversation between Joe and Jane:\\nJoe: How'\\''s it going today Jane?\\nJane: Not too bad, how about you?",

&#x20;   "voice": "Kore",

&#x20;   "response\_format": "wav",

&#x20;   "instructions": "Joe should sound firm and professional, Jane should sound upbeat and friendly"

&#x20; }' \\

&#x20; --output conversation.wav

```



\### Python Example (OpenAI SDK)



```python theme={null}

from openai import OpenAI



client = OpenAI(

&#x20;   api\_key="your-aihubmix-api-key",

&#x20;   base\_url="https://aihubmix.com/v1"

)



response = client.audio.speech.create(

&#x20;   model="tts-1",

&#x20;   voice="alloy",

&#x20;   input="The quick brown fox jumped over the lazy dog."

)



response.stream\_to\_file("speech.mp3")

```



\### Python Example (Gemini TTS)



```python theme={null}

from openai import OpenAI



client = OpenAI(

&#x20;   api\_key="your-aihubmix-api-key",

&#x20;   base\_url="https://aihubmix.com/v1"

)



\# Single Speaker

response = client.audio.speech.create(

&#x20;   model="gemini-2.5-flash-preview-tts",

&#x20;   voice="Kore",

&#x20;   input="Say cheerfully: Have a wonderful day!",

&#x20;   extra\_body={

&#x20;       "response\_format": "wav"

&#x20;   }

)



response.stream\_to\_file("speech.wav")



\# Multi-Speaker Dialogue

conversation\_response = client.audio.speech.create(

&#x20;   model="gemini-2.5-flash-preview-tts",

&#x20;   voice="Kore",

&#x20;   input="""TTS the following conversation between Joe and Jane:

&#x20;   Joe: How's it going today Jane?

&#x20;   Jane: Not too bad, how about you?""",

&#x20;   extra\_body={

&#x20;       "response\_format": "wav",

&#x20;       "instructions": "Joe should sound firm, Jane should sound upbeat"

&#x20;   }

)



conversation\_response.stream\_to\_file("conversation.wav")

```



\## Controlling Voice Style (Gemini Models)



Gemini TTS models support controlling voice style, tone, accent, and speed through natural language prompts. You can provide guidance in the `input` or `instructions` parameters.



\### Single Speaker Style Control



```json theme={null}

{

&#x20; "model": "gemini-2.5-flash-preview-tts",

&#x20; "input": "Say in a spooky whisper: By the pricking of my thumbs... Something wicked this way comes",

&#x20; "voice": "Enceladus",

&#x20; "response\_format": "wav"

}

```



\### Multi-Speaker Style Control



```json theme={null}

{

&#x20; "model": "gemini-2.5-flash-preview-tts",

&#x20; "input": "Speaker1: So... what's on the agenda today?\\nSpeaker2: You're never going to guess!",

&#x20; "voice": "Kore",

&#x20; "response\_format": "wav",

&#x20; "instructions": "Make Speaker1 sound tired and bored, and Speaker2 sound excited and happy"

}

```



\### Prompt Structure Recommendations



For best results, you can use the following structured prompt format:



```json theme={null}

{

&#x20; "model": "gemini-2.5-flash-preview-tts",

&#x20; "input": "Your transcript here",

&#x20; "voice": "Kore",

&#x20; "instructions": "# AUDIO PROFILE: Character Name\\n## Role Description\\n\\n## THE SCENE: Scene Name\\nDescribe the environment and mood\\n\\n### DIRECTOR'S NOTES\\nStyle: Describe the style\\nPacing: Describe the pacing\\nAccent: Specify the accent"

}

```



\## Supported Languages



The TTS models automatically detect the input language. The following 24 languages are supported:



| Language               | BCP-47 Code   | Language             | BCP-47 Code |

| :--------------------- | :------------ | :------------------- | :---------- |

| Arabic (Egypt)         | ar-EG         | German (Germany)     | de-DE       |

| English (US)           | en-US         | Spanish (US)         | es-US       |

| French (France)        | fr-FR         | Hindi (India)        | hi-IN       |

| Indonesian (Indonesia) | id-ID         | Italian (Italy)      | it-IT       |

| Japanese (Japan)       | ja-JP         | Korean (South Korea) | ko-KR       |

| Portuguese (Brazil)    | pt-BR         | Russian (Russia)     | ru-RU       |

| Dutch (Netherlands)    | nl-NL         | Polish (Poland)      | pl-PL       |

| Thai (Thailand)        | th-TH         | Turkish (Turkey)     | tr-TR       |

| Vietnamese (Vietnam)   | vi-VN         | Romanian (Romania)   | ro-RO       |

| Ukrainian (Ukraine)    | uk-UA         | Bengali (Bangladesh) | bn-BD       |

| English (India)        | en-IN \& hi-IN | Marathi (India)      | mr-IN       |

| Tamil (India)          | ta-IN         | Telugu (India)       | te-IN       |



\## Response Formats



\### Audio Formats



| Format | Content-Type | Description                         | Model Support |

| :----- | :----------- | :---------------------------------- | :------------ |

| mp3    | audio/mpeg   | Default format, widely compatible   | OpenAI Models |

| opus   | audio/opus   | Suitable for internet streaming     | OpenAI Models |

| aac    | audio/aac    | Digital audio compression           | OpenAI Models |

| flac   | audio/flac   | Lossless audio compression          | OpenAI Models |

| wav    | audio/wav    | Uncompressed WAV audio              | All Models    |

| pcm    | audio/pcm    | Raw PCM audio (24kHz, mono, 16-bit) | All Models    |



\*\*Note:\*\* The Gemini model natively returns PCM format (24kHz, mono, 16-bit), and the system will automatically convert it to WAV format. For other formats, it's recommended to use OpenAI models.



\### Response Body



On success, an audio stream (binary data) is returned, and Content-Type is set according to the `response\_format` parameter.



On failure, a JSON error message is returned:



```json theme={null}

{

&#x20; "error": {

&#x20;   "message": "Error description",

&#x20;   "type": "error\_type",

&#x20;   "code": "error\_code"

&#x20; }

}

```



\## Billing Information



The TTS API is billed based on the number of characters:



\* The character count of the input text is the billing unit

\* Different models have different price multipliers

\* Maximum input length: 4096 characters



\## Limitations



\* Maximum input length: 4096 characters

\* Gemini TTS models only support `wav` and `pcm` output formats

\* Gemini TTS models do not support the `speed` parameter (controlled through prompts)

\* Context window limit: 32k tokens (Gemini models)



\## Frequently Asked Questions



\### Q: How do I choose the right model?



\* Need quick generation → `tts-1` or `gemini-2.5-flash-preview-tts`

\* Need high-quality audio → `tts-1-hd`

\* Need intelligent voice control → `gpt-4o-mini-tts` or Gemini TTS models

\* Need multi-speaker dialogues → Gemini TTS models



\### Q: What are the differences between Gemini TTS and OpenAI TTS?



\* \*\*Gemini TTS\*\*: Supports controlling voice style through natural language prompts, supports multiple speakers, but only WAV/PCM formats

\* \*\*OpenAI TTS\*\*: Supports multiple audio formats, has fixed voice options, and speed can be controlled via parameters



\### Q: How do I implement multi-speaker dialogues?



Use the Gemini TTS model, format the `input` as a dialogue, and specify the style for each speaker in the `instructions`:



```json theme={null}

{

&#x20; "model": "gemini-2.5-flash-preview-tts",

&#x20; "input": "Speaker1: Hello!\\nSpeaker2: Hi there!",

&#x20; "instructions": "Speaker1 should sound professional, Speaker2 should sound casual"

}

```



\### Q: Is streaming output supported?



Currently, the TTS API returns complete audio files and does not support streaming output.



