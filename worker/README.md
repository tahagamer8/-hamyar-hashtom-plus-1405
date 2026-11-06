# Fahmino Worker

The deployed Worker is intentionally in offline-only mode.

- `GET /health` reports that external AI is disabled.
- `POST /api/chat` returns HTTP 410 and never calls a model provider.
- No model API key or paid service is used by this Worker.

Fahmino is a grade-eight learning app and its intended audience includes people under 18. The current Gemini API Additional Terms require API users to be 18+ and prohibit using the API in apps directed to or likely accessed by under-18 users. Therefore this Worker must remain disabled for external Gemini calls. See Google's current terms: https://ai.google.dev/gemini-api/terms

The app uses a local, on-device content helper instead. It searches the authored Fahmino catalog and does not send lesson questions or personal information to a remote AI provider.
