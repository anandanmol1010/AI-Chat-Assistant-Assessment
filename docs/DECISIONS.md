# Engineering Decisions

Format: context, decision, trade-off. Status is `proposed` until the code confirms it.

## 1. SQLite (sqflite) over Hive
- **Context:** conversations have many messages; deleting a conversation must remove its messages
- **Decision:** SQLite with foreign keys and `ON DELETE CASCADE`
- **Trade-off:** more boilerplate than Hive, but relational integrity, indexed queries, and easy search later
- **Status:** implemented for conversation and message history

## 2. API key in secure storage, not in the database
- **Context:** the suggested schema has `apiKey` in the providers table
- **Decision:** store the key in `flutter_secure_storage`; SQLite stores one active configuration with an opaque key reference. Write the new key before committing its reference, then remove the previous key
- **Trade-off:** one more storage layer; reduces exposure when the SQLite database is copied
- **Status:** implemented

## 3. Provider abstraction by API shape
- **Context:** OpenAI, OpenRouter, LM Studio share one request format; Gemini differs
- **Decision:** two datasources behind one `ChatRepository`, chosen by a factory using the protocol in the active config, independently of the editable display name and base URL
- **Trade-off:** small factory to maintain; new providers need no Bloc change
- **Status:** proposed

## 4. Use cases between Bloc and repositories
- **Context:** the required structure includes `domain/usecases`
- **Decision:** one use case per action; Blocs depend only on use cases
- **Trade-off:** more small classes; Blocs become easy to test and stay free of data logic
- **Status:** proposed

## 5. Sealed events, states, and failures
- **Context:** need exhaustive handling in UI and tests
- **Decision:** Dart 3 sealed classes with `equatable`
- **Trade-off:** slightly more code; compiler catches unhandled states
- **Status:** proposed

## 6. `droppable()` for sending messages
- **Context:** duplicate requests must be blocked while waiting
- **Decision:** `bloc_concurrency` `droppable()` transformer on `MessageSent`, a shared send/retry guard, and a disabled send button during replies
- **Trade-off:** extra package; guard lives in the Bloc, not only in the UI
- **Status:** proposed

## 7. Either-style results instead of throwing across layers
- **Context:** errors must map to user-friendly messages
- **Decision:** repositories return `Either<Failure, T>` (`fpdart` or `dartz`); datasources throw, repositories catch and map
- **Trade-off:** extra package; error paths are explicit
- **Status:** proposed

## 8. Bonus features: streaming and markdown
- **Context:** pick any two
- **Decision:** streaming responses and markdown rendering
- **Trade-off:** streaming complicates state design, but shows Bloc stream handling, which is what is being evaluated
- **Status:** proposed

## 9. Dependency injection with get_it
- **Decision:** register datasources, repositories, use cases in `core/di`; provide Blocs with `BlocProvider` at screen level
- **Trade-off:** simple and widely understood; no code generation
- **Status:** proposed

## 10. Visual design
- **Decision:** flat solid colors, one accent, system-like typography, no gradients; light and dark themes from one token set
- **Trade-off:** less flashy; consistent and quick to maintain
- **Status:** proposed
