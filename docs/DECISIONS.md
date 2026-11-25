# Engineering decisions

| Decision | Rationale and trade-off |
|---|---|
| SQLite with foreign keys | A chat and its messages have a clear ownership relationship. SQLite can cascade deletes and update history metadata atomically. This adds schema and migration work. |
| Secure storage for credentials | Only an opaque reference goes in SQLite. Save writes a fresh key, commits the reference, then removes the old key. Cleanup is best effort if secure storage is unavailable. |
| Provider adapters by request format | One codec handles OpenAI and compatible servers. Gemini has a separate codec for its message roles and response shape. An extra provider protocol can be wired without changing ChatBloc. |
| Use cases and constructor injection | Blocs take focused use cases. The composition root supplies concrete repositories and datasources. A single entry point makes dependencies visible and requires no service locator. |
| Sealed events and typed failures | Exhaustive handling helps when states or errors grow. Chat uses one snapshot with a phase so saved history stays visible during transient failures and streaming. |
| Shared droppable request gate | One ChatBloc handler blocks concurrent send and retry interactions. A persisted prompt can still be retried after a failed stream or restart. |
| Streaming and Markdown | Streaming exposes progress for slow requests. Persisting only complete assistant text keeps interrupted replies out of history. A settings toggle supports endpoints that return complete JSON. |
| Local-first conversation history | Listing, opening, and deleting run without network access. Model generation depends on the chosen endpoint. Prompts are explicitly retried by the user. |
