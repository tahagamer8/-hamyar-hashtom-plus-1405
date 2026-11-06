# Fahmino Gemini Worker

This directory tracks the module currently deployed as Cloudflare Worker `fahmino-api-2`.

## Required bindings

- Secret text binding: `GEMINI_API_KEY` (Google Gemini Developer API key; keep it in Cloudflare Secrets, never commit it).
- Rate-limit binding: `CHAT_LIMITER` (20 requests per IP per 60 seconds).

## API

- `GET /health`: reports whether the required bindings exist; it does not send a Gemini request.
- `POST /api/chat`: accepts alternating `user` / `model` messages and optional lesson context.

## Model and cost safeguards

The worker currently uses `gemini-3.8-flash`. Google's Gemini Developer API pricing page lists Standard Free Tier input and output tokens for this model as free of charge, subject to quotas and eligibility. Do not enable a paid billing tier or add paid tools/grounding without an adult account owner reviewing the settings first.

The per-IP rate limit is an abuse-control measure, not a guaranteed monthly spending cap. Check Google AI Studio / API project usage and quotas regularly. A configured API key alone does not prove that the project is on the Free Tier.

## Deployment note

The production Worker is managed in Cloudflare. Keep this source file synchronized with the deployed script before future deployments. Never copy secret values into this repository.
