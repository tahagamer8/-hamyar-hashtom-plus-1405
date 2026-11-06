import test, { afterEach } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";

const originalFetch = globalThis.fetch;
afterEach(() => {
  globalThis.fetch = originalFetch;
});

function makeRequest({ method = "POST", path = "/api/chat", body, headers = {} } = {}) {
  return new Request(`https://worker.example${path}`, {
    method,
    headers: { "content-type": "application/json", ...headers },
    body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body),
  });
}

const validBody = {
  messages: [{ role: "user", text: "عدد گویا چیست؟" }],
};

test("answers CORS preflight without requiring an API key", async () => {
  const response = await worker.fetch(makeRequest({ method: "OPTIONS" }), {});
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("access-control-allow-origin"), "*");
});

test("rejects unknown paths", async () => {
  const response = await worker.fetch(makeRequest({ path: "/wrong" }), {});
  assert.equal(response.status, 404);
});

test("rejects malformed JSON", async () => {
  const response = await worker.fetch(makeRequest({ body: "{" }), { GEMINI_API_KEY: "test" });
  assert.equal(response.status, 400);
});

test("rejects null and invalid message payloads without throwing", async () => {
  for (const body of ["null", { messages: [] }, { messages: [{ role: "system", text: "x" }] }]) {
    const response = await worker.fetch(makeRequest({ body }), { GEMINI_API_KEY: "test" });
    assert.equal(response.status, 400);
  }
});

test("returns a clear configuration error when the API key is missing", async () => {
  const response = await worker.fetch(makeRequest({ body: validBody }), {});
  assert.equal(response.status, 503);
});

test("forwards valid chat and returns Gemini text", async () => {
  let capturedUrl;
  let capturedInit;
  globalThis.fetch = async (url, init) => {
    capturedUrl = String(url);
    capturedInit = init;
    return new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: "عدد گویا را می‌توان به شکل کسر نوشت." }] } }],
    }), { status: 200, headers: { "content-type": "application/json" } });
  };

  const response = await worker.fetch(makeRequest({ body: validBody }), { GEMINI_API_KEY: "test-key" });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).answer, "عدد گویا را می‌توان به شکل کسر نوشت.");
  assert.equal(capturedUrl, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent");
  assert.equal(capturedInit.headers["x-goog-api-key"], "test-key");
  assert.equal(JSON.parse(capturedInit.body).contents[0].role, "user");
});

test("maps Gemini quota responses to HTTP 429", async () => {
  globalThis.fetch = async () => new Response(JSON.stringify({ error: { message: "quota" } }), { status: 429 });
  const response = await worker.fetch(makeRequest({ body: validBody }), { GEMINI_API_KEY: "test-key" });
  assert.equal(response.status, 429);
  assert.match((await response.json()).error, /سهمیه/);
});

test("stops before calling Gemini when the rate limiter denies a request", async () => {
  let called = false;
  globalThis.fetch = async () => {
    called = true;
    throw new Error("Gemini must not be called");
  };
  const response = await worker.fetch(makeRequest({ body: validBody }), {
    GEMINI_API_KEY: "test-key",
    CHAT_LIMITER: { limit: async () => ({ success: false }) },
  });
  assert.equal(response.status, 429);
  assert.equal(called, false);
});

test("rejects more than 12 messages and messages longer than 3000 characters", async () => {
  const tooMany = { messages: Array.from({ length: 13 }, () => ({ role: "user", text: "سلام" })) };
  const tooLong = { messages: [{ role: "user", text: "ا".repeat(3001) }] };
  for (const body of [tooMany, tooLong]) {
    const response = await worker.fetch(makeRequest({ body }), { GEMINI_API_KEY: "test-key" });
    assert.equal(response.status, 400);
  }
});

test("maps non-quota Gemini failures to a generic 502 without leaking provider details", async () => {
  globalThis.fetch = async () => new Response(JSON.stringify({
    error: { message: "sensitive upstream diagnostic" },
  }), { status: 500 });
  const response = await worker.fetch(makeRequest({ body: validBody }), { GEMINI_API_KEY: "test-key" });
  assert.equal(response.status, 502);
  const body = await response.json();
  assert.match(body.error, /سرویس هوش مصنوعی/);
  assert.doesNotMatch(body.error, /sensitive upstream diagnostic/);
});

test("returns a controlled error when Gemini has no text candidate", async () => {
  globalThis.fetch = async () => new Response(JSON.stringify({ candidates: [] }), { status: 200 });
  const response = await worker.fetch(makeRequest({ body: validBody }), { GEMINI_API_KEY: "test-key" });
  assert.equal(response.status, 502);
  assert.match((await response.json()).error, /پاسخ متنی/);
});
