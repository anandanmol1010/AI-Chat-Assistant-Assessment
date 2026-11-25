# AI usage report

## Tools used

| Tool | Contribution |
|---|---|
| Claude | Initial planning and architecture discussion, as recorded in the original planning draft |
| OpenAI Codex | Assessment review, implementation, automated tests, debugging, documentation, and local Git commits |

## Prompt summaries

- Review the assessment and existing documentation for missing or inconsistent requirements.
- Initialize Flutter and develop offline conversation management with SQLite and Bloc.
- Implement the remaining provider, persistence, chat, and bonus requirements. Verify each milestone and document the engineering trade-offs.

## Generated code

Codex generated and revised the Flutter app code, native project configuration, and automated tests. Flutter tooling generated the baseline platform scaffolds. Codex also drafted and updated project documentation.

## Manually written code

No manually written Dart code was recorded during this implementation session. The applicant supplied the assessment, initial project documentation, and implementation priorities. Applicant review of the final implementation is pending.

## Engineering decisions

- Keep conversation history in relational SQLite tables and store credential bytes in device secure storage.
- Share one ChatBloc request gate across send and retry. Persist the prompt before requesting a reply and reuse that row when retrying.
- Choose the API adapter by protocol independently of the editable display name. Allow a single JSON reply when streaming is unsuitable for the configured endpoint.
- Use streaming and Markdown for the two assessment bonuses. Keep incomplete streamed replies out of persistent history.

## Verification

Codex ran static analysis and automated Flutter tests. HTTP adapter tests use known response fixtures. Database tests use SQLite through FFI, and credential tests use a mock secure-storage implementation.
