# Architecture

SQLite history and ConversationBloc are implemented. ChatBloc, SettingsBloc, and provider integration describe planned implementation.

## Layers and dependency rule

```
presentation  ->  domain  <-  data
(Bloc, UI)       (entities,    (SQLite, HTTP,
                  usecases,     secure storage,
                  repo ifaces)  repo impls)
```

- `domain` is pure Dart. No Flutter, no packages except `equatable` and `dartz`/`fpdart` (if used).
- `data` implements domain interfaces.
- `presentation` talks to domain through use cases only.
- Dependencies are wired in `core/di` with `get_it`.

## Entities

- `Conversation { id, title, createdAt, updatedAt }`
- `Message { id, conversationId, role, content, timestamp }`
- `ProviderConfig { id, providerName, protocol, baseUrl, model, isActive }`
- `MessageRole { user, assistant, system }`

## Use cases

| Use case | Used by |
|---|---|
| `GetConversations`, `CreateConversation`, `GetConversation`, `DeleteConversation` | ConversationBloc |
| `GetMessages`, `SendMessage`, `StreamAssistantReply` | ChatBloc |
| `GetProviders`, `SaveProvider`, `SetActiveProvider`, `DeleteProvider` | SettingsBloc |

## Provider abstraction

One interface in domain:

```
abstract class ChatRepository {
  Future<Either<Failure, Message>> send(...);
  Stream<Either<Failure, String>> stream(...);
}
```

Data layer has two remote datasources behind it:

- `OpenAiCompatibleDataSource`: OpenAI, OpenRouter, LM Studio (same `/chat/completions` shape)
- `GeminiDataSource`: Gemini `generateContent` / `streamGenerateContent`

A small factory picks the datasource from the protocol in the active `ProviderConfig` (Gemini or OpenAI-compatible). Adding a new provider means adding one datasource, with no change in Bloc or UI.

## Error model

Sealed `Failure` hierarchy in `core/errors`:

| Failure | Triggered by |
|---|---|
| `NetworkFailure` | no connection, DNS, socket errors |
| `TimeoutFailure` | connect or receive timeout |
| `AuthFailure` | 401, 403 |
| `RateLimitFailure` | 429 (carries retry-after if present) |
| `InvalidResponseFailure` | malformed JSON, missing fields, empty choices |
| `ServerFailure` | 5xx |
| `StorageFailure` | SQLite or secure storage errors |
| `ConfigFailure` | missing provider, invalid configuration, or missing key for a provider that requires one |

Each failure maps to one user-facing message in the presentation layer.

## Bloc design

### ChatBloc

Events: `ChatOpened(conversationId)`, `MessageSent(text)`, `ChatRetryRequested`, `ChatErrorDismissed`

States (sealed, with Equatable): `ChatInitial`, `ChatLoading`, `ChatSuccess(messages, isReplying, partialReply)`, `ChatError(failure, messages, retryableMessageId)`

Rules:
- `MessageSent` uses `droppable()`. Send and retry also share a single in-flight guard so either event is ignored while a reply is pending.
- Empty or whitespace text is rejected before it reaches the repository
- Save the user message before calling the provider. Clear the composer when that write succeeds and retain the draft if the write fails.
- Retry by reusing the saved user message ID and its conversational history. Keep partial output in memory and persist the assistant message only once the stream finishes.
- Streaming: tokens are emitted into `partialReply`, saved once complete
- Error state keeps the existing messages so the screen never goes blank

### ConversationBloc

Events: `ConversationsRequested`, `ConversationCreated`, `ConversationOpened(id)`, `ConversationDeleted(id)`. Resolve the selected ID locally and let the UI navigate on success.

States: `ConversationLoading`, `ConversationLoaded(list)`, `ConversationEmpty`, `ConversationError`

Conversation events share a sequential queue to preserve the order of reads and mutations. The history screen handles navigation when the Bloc returns a selected conversation. SQLite titles start as "New chat" and take the first eight words of the first saved user message.

### SettingsBloc

Events: `SettingsRequested`, `ProviderSaved`, `ProviderSelected`, `ProviderDeleted`

States: `SettingsLoading`, `SettingsLoaded(providers, active)`, `SettingsError`

## Data flow: sending a message

```
UI -> ChatBloc(MessageSent) -> SendMessage usecase
   -> ChatRepository -> local save(user msg)
   -> remote datasource (provider chosen from active config)
   -> local save(assistant msg) -> ChatBloc emits ChatSuccess
```

Failure at any step returns `Left(Failure)` and the Bloc emits `ChatError`.

## Offline behavior

- All reads come from SQLite, so history works with no network
- Sending offline reports `NetworkFailure`; the user's message stays saved and can be retried

## Testing strategy

- `bloc_test` for all three Blocs with mocked use cases
- Repository tests with fake datasources
- Datasource tests for error mapping (status code to Failure)
