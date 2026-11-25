# AI Chat Assistant

A Flutter chat app that talks to configurable AI providers (OpenAI, Gemini, any OpenAI-compatible endpoint) and keeps every conversation on the device.

> Status: The app implements offline conversation history, configurable providers, and AI chat with streaming and Markdown.

## Features

Saved conversations stay available offline. If a reply fails, retry the saved prompt directly from the chat.

- Create, open, and delete conversations
- Chat screen with user and assistant bubbles, timestamps, multiline composer
- Typing and request progress indicators, duplicate-request guard, empty-message guard
- Provider settings: name, base URL, API key, model (persisted)
- Providers: OpenAI, Gemini, any OpenAI-compatible endpoint (OpenRouter, LM Studio, ...)
- Full offline read access to saved conversations and messages
- Typed error handling: network, timeout, auth, rate limit, invalid response
- Bonuses: streaming responses, Markdown rendering, offline search, persisted dark mode, and multiple saved provider profiles

## Setup

Use Flutter 3.44 or newer with an Android emulator or device, or macOS with Xcode for iOS.

```bash
flutter --version
git clone https://github.com/anandanmol1010/AI-Chat-Assistant-Assessment.git
cd AI-Chat-Assistant-Assessment
flutter pub get
flutter run
```

Open **Provider settings**, choose a protocol, enter the base URL and model ID, then save. If a compatible endpoint supports only full JSON responses, turn off **Stream replies**. Select **New profile** to save another configuration. Selecting a saved profile activates it for subsequent chat requests.

| Provider | Base URL | Notes |
|---|---|---|
| OpenAI | `https://api.openai.com/v1` | API key required |
| OpenRouter | `https://openrouter.ai/api/v1` | API key required |
| LM Studio | `http://localhost:1234/v1` | Android emulator: use `http://10.0.2.2:1234/v1`. Leave the key blank for HTTP. |
| Gemini | `https://generativelanguage.googleapis.com/v1beta` | API key required |

For a keyless LM Studio server running on your computer, an Android phone connected over USB can reach it using `adb reverse tcp:1234 tcp:1234` and base URL `http://127.0.0.1:1234/v1`. Use the model ID shown by LM Studio. Other remote endpoints use HTTPS.

## Environment Variables

The app needs **no** environment variables to run. Provider details are entered in the Settings screen, and the API key is stored in the device's secure storage.

Enter API keys on the device. Keep them out of build flags and Git. Each request sends the current conversation transcript to the configured endpoint. Use HTTPS for remote hosts and for any connection that sends a key.

## Application Architecture

Three layers with a one-way dependency rule: `presentation -> domain <- data`.

```
lib/
  core/            shared failure types
  data/
    datasources/   SQLite schema, provider codecs, and SSE framing
    models/        DTOs and mappers to/from entities
    repositories/  SQLite, secure storage, and HTTP repository implementations
  domain/
    entities/      Conversation, Message, ProviderConfig
    repositories/  abstract interfaces
    usecases/      one class per business action
  presentation/
    blocs/         ChatBloc, ConversationBloc, SettingsBloc
    screens/
    widgets/
  main.dart        app composition and dependency wiring
```

Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Reasons behind choices: [docs/DECISIONS.md](docs/DECISIONS.md).

## Bloc Architecture Overview

| Bloc | Responsibility | Key events | States |
|---|---|---|---|
| `ConversationBloc` | list, create, delete, open conversations | `ConversationsRequested`, `ConversationCreated`, `ConversationOpened`, `ConversationDeleted` | `ConversationLoading`, `ConversationLoaded`, `ConversationEmpty`, `ConversationError` |
| `ChatBloc` | load messages, send prompt, receive reply, errors | `ChatOpened`, `MessageSent`, `ChatRetryRequested` | `ChatState` with loading, ready, saving, replying, and history-error phases |
| `SettingsBloc` | provider profiles and provider settings | `SettingsRequested`, profile selection, provider draft edits, `ProviderSaved` | `SettingsLoading`, `SettingsLoaded`, `SettingsError` |

The feature Blocs call use cases for application operations. Startup retry, provider form edits, and composer availability also use Bloc events and state.

## Local Storage Design

SQLite (`sqflite`) stores conversation and message history with foreign keys enabled. Timestamps use UTC epoch microseconds. Message insertion, first-message title, and conversation recency are updated in one transaction. Provider metadata and an opaque key reference are stored separately from the key.

```
conversations(id TEXT PK, title TEXT, created_at INT, updated_at INT)
messages(id TEXT PK, conversation_id TEXT FK -> conversations ON DELETE CASCADE,
         role TEXT, content TEXT, timestamp INT)
provider_settings(id INTEGER PK, active INT, provider_name TEXT, protocol TEXT, base_url TEXT, model TEXT, key_ref TEXT, stream_replies INT)
app_preferences(id INTEGER PK, dark_mode INT)
```

Each provider profile has its own secure-storage key reference. A SQLite constraint permits one active profile at a time. Earlier single-provider installs migrate their settings and key reference into the first profile.

## Testing

```bash
flutter analyze
flutter test
```

Tests cover app launch, SQLite reopen persistence, duplicate inserts, cascading deletion, and the ConversationBloc create/open/delete flow. Additional tests cover provider settings, OpenAI-compatible and Gemini request formats, streaming, processing feedback, HTTP and transport errors, duplicate-free retry, offline search, theme persistence, and provider profile migration and switching.

### Physical Android verification

The ARM64 debug APK was built, installed over USB, and launched on an RMX3085 running Android 13 on 26 November 2026. A local OpenAI-compatible HTTP fixture returned a rate limit on the first request and a streamed Markdown reply on retry. The phone displayed one copy of the prompt, reopened the saved transcript after an app restart with the fixture disconnected, kept a new prompt visible after a connection failure, and deleted the test conversation. The same phone also completed five connected turns against the live Gemini API with `gemini-2.5-flash` and streaming enabled. Live OpenAI remains unverified.

### Manual smoke test

1. Configure one provider and send a multiline prompt that asks for a list and a code block. Watch the text stream in and confirm the final reply renders as Markdown.
2. Restart the app with networking disabled. Open the saved conversation and confirm both messages remain visible.
3. Send a message while offline. Reconnect, tap **Retry**, and confirm that the saved prompt appears only once.
4. Delete the conversation, confirm the dialog, and restart to verify that it was removed.

## AI Usage

See [AI_USAGE.md](AI_USAGE.md).
