# Strict Official Chapter Mapping Implementation Plan

> **For agentic workers:** Use this plan task by task. Each task ends with a testable result.

**Goal:** Make the content audit require parsed official-PDF evidence and a chapter-level title/page mapping before marking any section source-mapped.

**Architecture:** Keep the existing JSON chapter packs unchanged unless they contain verified evidence. Strengthen the Python audit contract, report independent source and educational-completeness states, and rely on CI to regenerate the JSON/Markdown artifacts.

**Tech Stack:** Python 3 standard library, unittest, existing GitHub Actions Flutter/Python workflow.

**Spec:** `docs/superpowers/specs/2026-11-09-official-pdf-chapter-mapping-design.md`

## Global Constraints
- Do not modify or merge `main`.
- Do not infer official chapter titles or pages from internal pack data.
- Do not set PDF parsing status without evidence from the official PDF.
- Do not copy textbook body text or page images.
- Preserve the existing 13-pack schema and Flutter functionality.

## Review Focus
- A legacy `textbookContentsVerified=true` flag must not bypass PDF evidence.
- Portal URL, edition and internal page range alone must not count as a chapter match.
- Missing, malformed, reversed or non-positive PDF page values must be rejected.
- Invalid verification method/date/title must be rejected.
- Educational gaps must remain visible even when source status takes precedence.

---

### Task 1: Lock the source-evidence contract with tests

**Files:**
- Modify: `tooling/test_content_quality_audit.py`
- Modify: `tooling/audit_content_quality.py`

**Interfaces:**
- `source_is_mapped(pack, chapter) -> bool` accepts only a parsed official source plus an exact per-chapter mapping.
- The mapping uses `officialTextbookMapping` with `status`, `officialTitle`, `pdfPageStart`, `pdfPageEnd`, `verificationMethod` and `verifiedAt`.

- [ ] Add tests proving that portal metadata, internal page numbers, sourceLesson and legacy flags are insufficient.
- [ ] Add tests for invalid page ranges, missing title, unsupported verification method and invalid date.
- [ ] Add a positive fixture containing a parsed source and fully evidenced mapping.
- [ ] Run the Python tests and confirm the new assertions fail against the old implementation.
- [ ] Implement the strict evidence predicate and update the positive fixture.
- [ ] Re-run tests and confirm all pass.

### Task 2: Separate alignment status from pedagogical status

**Files:**
- Modify: `tooling/audit_content_quality.py`
- Regenerate: `research/content-quality-audit-2026-11-09.json`
- Regenerate: `research/content-quality-audit-2026-11-09.md`

- [ ] Add `sourceStatus`, `educationallyIncomplete`, and per-section evidence fields.
- [ ] Count source-unverified sections separately from educationally-incomplete sections.
- [ ] Keep the final status conservative: no source evidence means `نیازمند منبع`; only both dimensions passing may be `کامل`.
- [ ] Verify that all current sections remain non-complete because the official PDFs are not yet parsed.
- [ ] Record current official portal records separately from PDF-content parsing.

### Task 3: Verify and deliver

**Files:**
- Modify: `.github/workflows/build_apk.yml` only if required; otherwise no workflow change.
- Update PR description with evidence and limitations.

- [ ] Run Python unit tests and content audit.
- [ ] Run `flutter analyze` and `flutter test`.
- [ ] Confirm CI status and artifacts on the branch.
- [ ] Review diff and confirm no write targeted `main`.
- [ ] Commit all changes to `audit/content-quality-gate-2026-11-09`; leave PR #7 open and unmerged.
