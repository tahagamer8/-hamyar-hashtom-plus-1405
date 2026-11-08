# Fahmino Worker

## Deployment policy

The grade-eight Fahmino app uses an on-device study guide and does not send student questions or chat history to a remote model provider.

- `GET /health` reports `mode: offline` and `externalAiEnabled: false`.
- `POST /api/chat` returns HTTP 410; no external model request is made.
- No model API key is needed by this Worker.
- The Flutter app searches its bundled subject packs locally, including lesson summaries, key points, examples, worked steps, questions and `commonMistakes`.

## Why this Worker does not call Gemini

Google's Gemini API Additional Terms, effective March 23, 2026, say API users must be 18+ and prohibit using the API in applications directed to or likely to be accessed by people under 18. Fahmino is a grade-eight learning app, so it must not send student content to Gemini API.

Official terms: https://ai.google.dev/gemini-api/terms
