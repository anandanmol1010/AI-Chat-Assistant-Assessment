# AI Chat Assistant

A Flutter chat app that talks to configurable AI providers (OpenAI, Gemini, any OpenAI-compatible endpoint) and keeps every conversation on the device.

> Status: The Android and iOS app can create, open, list, and delete local conversations through ConversationBloc. Provider configuration is available. Message sending is planned.

## Features

Available now: offline conversation management and a read-only history view. Remaining items below are planned.

- Create, open, and delete conversations
- Chat screen with user and assistant bubbles, timestamps, multiline composer
- Typing indicator, duplicate-request guard, empty-message guard
- Provider settings: name, base URL, API key, model (persisted)
- Providers: OpenAI, Gemini, any OpenAI-compatible endpoint (OpenRouter, LM Studio, ...)
- Full offline read access to saved conversations and messages
- Typed error handling: network, timeout, auth, rate limit, invalid response
- Bonus: streaming responses, markdown rendering

## Setup

Use Flutter 3.44 or newer with an Android emulator or device, or macOS with Xcode for iOS.

```bash
flutter --version
git clone <repo-url>
cd AI-Chat-Assistant-Assessment
flutter pub get
flutter run
```

Open **Provider settings**, choose a protocol, enter the base URL and model ID, then save.

| Provider | Base URL | Notes |
|---|---|---|
| OpenAI | `https://api.openai.com/v1` | API key required |
| OpenRouter | `https://openrouter.ai/api/v1` | API key required |
| LM Studio | `http://localhost:1234/v1` | Android emulator: use `http://10.0.2.2:1234/v1` |
| Gemini | `https://generativelanguage.googleapis.com/v1beta` | API key required |

## Environment Variables

The app needs **no** environment variables to run. Provider details are entered in the Settings screen, and the API key is stored in the device's secure storage.

Enter API keys on the device. Keep them out of build flags and Git.

## Application Architecture

Three layers with a one-way dependency rule: `presentation -> domain <- data`.

```
lib/
  core/            errors (Failure), constants, theme, utils, DI
  data/
    datasources/   SQLite (local), HTTP clients (remote), secure storage
    models/        DTOs and mappers to/from entities
    repositories/  implementations of domain repository interfaces
  domain/
    entities/      Conversation, Message, ProviderConfig
    repositories/  abstract interfaces
    usecases/      one class per business action
  presentation/
    blocs/         ChatBloc, ConversationBloc, SettingsBloc
    screens/
    widgets/
  main.dart
```

Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Reasons behind choices: [docs/DECISIONS.md](docs/DECISIONS.md).

## Bloc Architecture Overview

| Bloc | Responsibility | Key events | States |
|---|---|---|---|
| `ConversationBloc` | list, create, delete, open conversations | `ConversationsRequested`, `ConversationCreated`, `ConversationOpened`, `ConversationDeleted` | `ConversationLoading`, `ConversationLoaded`, `ConversationEmpty`, `ConversationError` |
| `ChatBloc` | load messages, send prompt, receive reply, errors | `ChatOpened`, `MessageSent`, `ChatRetryRequested` | `ChatInitial`, `ChatLoading`, `ChatSuccess`, `ChatError` |
| `SettingsBloc` | provider and app settings | `SettingsRequested`, `ProviderSaved` | `SettingsLoading`, `SettingsLoaded`, `SettingsError` |

Blocs depend only on use cases. They never touch HTTP, SQLite, or storage directly.

## Local Storage Design

SQLite (`sqflite`) stores conversation and message history with foreign keys enabled. Timestamps use UTC epoch microseconds. Message insertion, first-message title, and conversation recency are updated in one transaction. Provider metadata and an opaque key reference are stored separately from the key.

```
conversations(id TEXT PK, title TEXT, created_at INT, updated_at INT)
messages(id TEXT PK, conversation_id TEXT FK -> conversations ON DELETE CASCADE,
         role TEXT, content TEXT, timestamp INT)
provider_settings(id INTEGER PK, provider_name TEXT, protocol TEXT, base_url TEXT, model TEXT, key_ref TEXT)
```

API keys are **not** in SQLite. They live in `flutter_secure_storage`, referenced by an opaque ID. The app stores one active configuration.

## Testing

```bash
flutter test
```

Tests cover app launch, SQLite reopen persistence, duplicate inserts, cascading deletion, and the ConversationBloc create/open/delete flow. ChatBloc, SettingsBloc, and provider error tests are planned.

## AI Usage

See [AI_USAGE.md](AI_USAGE.md).
