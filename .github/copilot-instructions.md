# Fahmino review instructions

Review this repository as a Persian-language grade 8 learning app. Do not assume that a passing build proves educational correctness.

## Review priorities
1. Correctness and safety of educational explanations, answer keys, worked examples, and page/lesson references. Flag claims that are not traceable to the official edition or an explicitly authored source.
2. Persian RTL layout, typography, accessibility, small-screen behavior, and dark/light themes.
3. Offline behavior, persistence, navigation, PDF preview/download separation, and compatibility with existing saved data.
4. Gemini/Cloudflare integration: secrets must remain server-side; inspect timeouts, response validation, rate limits, error handling, prompt injection, privacy, and safe fallback behavior. Never expose API keys or secrets.
5. Flutter architecture, state lifecycle, resource disposal, performance, dependency risk, and test quality.
6. Copyright: do not recommend committing scans or substantial copied text from textbooks or competing apps without permission. Prefer original explanations and references to lesson/page identifiers.

## Required review method
- Read relevant surrounding files, not only the changed lines.
- Trace callers, data schemas, routes, and tests before declaring a bug or fix.
- Report concrete findings with file and line references, severity, impact, and a reproducible scenario.
- Separate confirmed defects from hypotheses and suggestions.
- Do not invent test results, content coverage, API verification, or device testing.
- Do not approve merely because CI passes. Check whether tests exercise the claimed behavior.
- Avoid broad rewrites when a focused, backward-compatible fix is safer.
