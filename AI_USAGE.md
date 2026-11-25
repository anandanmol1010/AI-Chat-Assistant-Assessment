# AI Usage Report

## AI Tools Used

I used OpenAI Codex for Flutter implementation, UI iterations, debugging, SQLite migrations, automated tests, and documentation. The original planning notes also record Claude for early architecture discussion.

## Prompts Used

- Move startup retry, provider form edits, and composer state to Bloc.
- Support multiple saved provider profiles, preserve existing settings during migration, and keep each profile's credentials separate.
- Make provider errors actionable and let users retry a saved prompt without adding a duplicate message.
- Simplify the conversation list and Settings after reviewing the app on a physical Android phone. Move the theme toggle next to Settings on the conversation screen.
- Store the model name used for each request with its completed reply so switching models preserves historical attribution.

## Generated Code

Codex drafted and revised substantial parts of the Flutter implementation, including Bloc flows, data access, provider integration, and UI. I used AI extensively while working through provider switching, error handling, and UI iterations. Codex also generated automated tests and helped investigate failures found during testing. Flutter tooling generated the initial platform scaffolds.

## Manually Written Code

I also worked on the code independently. I did not track manual and AI-assisted edits file by file, so I have not assigned percentages or claimed specific modules as exclusively hand-written.

My direct contributions included setting implementation priorities and checking the app on a physical Android phone. I used screenshots to identify visual and interaction issues, then requested specific changes to the conversation header, the placement of New chat and the theme toggle, and the alignment of provider settings actions.

## Engineering Decisions

| Decision | Rationale |
|---|---|
| Keep application behavior in Bloc | I asked for startup retry, provider editing, and composer availability to use Bloc. Explicit events and states make it easier to distinguish a draft edit, a local save, and a network request, and to test each transition. |
| Keep provider-specific behavior out of ChatBloc | The app uses one adapter for OpenAI-compatible requests and a separate adapter for Gemini. ChatBloc calls a use case and works with provider-independent reply data and typed failures. This keeps changes to request formats out of widgets and Bloc logic. |
| Save the prompt before sending and reuse it on retry | The chat remains usable after a network failure because SQLite already contains the prompt. Send and retry share a request guard. An assistant reply is saved after completion, so a broken stream leaves a retryable prompt and preserves previously saved history. |
| Separate credentials from profile metadata | SQLite stores the provider configuration and a key reference. Device secure storage holds the key. Profile switching updates the active selection in a transaction, and the next request reads that selection. |
| Preserve the model name on each reply | I requested that the chat display the exact model name from the configuration used for that request. Saving it with the reply keeps old labels correct after a model switch. Earlier replies display a generic assistant label because they have no saved model name. |
| Put frequent actions where they are used | On the phone, I found the theme control easier to reach alongside Settings on the conversation screen. I also requested one conversation heading, a floating New chat action, and consistent alignment for the secondary provider settings actions. |

[Architecture details](docs/ARCHITECTURE.md) and [engineering trade-offs](docs/DECISIONS.md).

## Verification

Static analysis passed and all 17 automated tests passed. The tests cover Bloc request handling, SQLite persistence and migrations, provider profile switching, and representative API responses. A physical Android smoke test used a local OpenAI-compatible fixture to exercise rate-limit feedback, retry, streamed Markdown, and reopening saved history after restart. The provider adapter tests use fixtures.
