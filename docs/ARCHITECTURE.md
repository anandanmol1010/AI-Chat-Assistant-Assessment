# Application architecture

## Dependencies and composition

```
presentation -> domain <- data
                 |
                 v
          shared failure types
```

`lib/main.dart` is the composition root. It opens one SQLite database, owns the Dio client, and wires repositories into use cases. The conversation list keeps one `ConversationBloc`. Each chat or settings route owns its Bloc. Widgets handle navigation and forward field edits as events. Bloc state controls startup retry, the provider draft, and composer availability. Blocs own application state and have no dependencies on SQLite, platform storage, or provider HTTP formats.

| Layer | Responsibility |
|---|---|
| `core/errors` | Typed failures shared by the application and adapters |
| `domain/entities` | Conversations, messages, and provider configuration |
| `domain/repositories`, `domain/usecases` | Persistence and generation contracts and application operations |
| `data/datasources`, `data/models`, `data/repositories` | SQLite, row mapping, secure storage, provider codecs and HTTP |
| `presentation/blocs`, `presentation/screens`, `presentation/widgets` | Application state, navigation, forms, and transcript rendering |

## Event and state boundaries

| Bloc | Events | State design |
|---|---|---|
| `ConversationBloc` | `ConversationsRequested`, `ConversationCreated`, `ConversationOpened`, `ConversationDeleted` | Loading, empty, loaded, and error. A loaded state may include the resolved conversation for navigation. Events share a sequential queue so reads and writes complete in order. |
| `ChatBloc` | `ChatOpened`, `MessageSent`, `ChatRetryRequested` | One snapshot carries saved messages, a phase, transient reply text, and an optional typed failure. A shared droppable event handler gates both send and retry. |
| `SettingsBloc` | `SettingsRequested`, profile creation and selection, provider draft edits, `ProviderSaved` | Loading, loaded, and error. Validation happens before writes. A failed save keeps the draft in Bloc state. |

An app-scoped ThemeBloc loads and saves the light or dark preference in SQLite. MaterialApp applies the selected theme across the conversation list, chat, and Settings without rebuilding the navigation stack.

## Message flow

1. Trim and validate the draft. Save the user message in SQLite. Clear the composer only after the write succeeds.
2. Load the provider configuration and pass the chronological transcript to its adapter.
3. Stream partial text into chat state. Persist the assistant message and the exact model name captured from the selected configuration at request start. Existing rows without a model show a generic assistant label. If streaming is disabled, parse one JSON reply and use the same save path.
4. For an empty, interrupted, or malformed response, keep the saved user message and show the error. Retry uses the same history without inserting another user row. Reopening a chat also offers retry if its last message is from the user.

Conversation search runs entirely in SQLite. It matches literal substrings in titles and saved messages and returns each conversation once, ordered by recency. Storage can be read and tested independently of any AI service. On a cold start the UI opens history directly from SQLite. Typed failures distinguish network problems, timeouts, credential rejection, rate limits, provider errors, malformed responses, and storage errors.

## Provider and storage boundaries

OpenAI and compatible servers use the same Chat Completions adapter. Gemini supplies a separate codec for request shape, roles, and response chunks. Both share Dio transport, server-sent event framing, and failure mapping. Redirects are disabled on provider requests. The request sends the current conversation transcript to the endpoint selected in Settings.

SQLite enforces message ownership through foreign keys with cascading deletion. Message insertion, conversation recency, and the first-message title run in one transaction. The versioned schema upgrades provider settings while preserving history. API keys live in device secure storage. SQLite references each profile key with an opaque ID. A partial unique index enforces a single active profile. Activation is transactional, and each reply reads the active profile at request start.

Streaming keeps partial text in memory. Markdown renders on completed assistant messages and shows image alt text without remote image requests. The stored transcript is sent without context-window truncation. Provider-side context limits still apply.

[OpenAI Chat Completions API](https://platform.openai.com/docs/api-reference/chat/create) · [Gemini content generation API](https://ai.google.dev/api/generate-content)
