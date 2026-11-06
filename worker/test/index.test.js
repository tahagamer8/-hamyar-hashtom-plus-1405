import test, { afterEach } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";

const originalFetch = globalThis.fetch;
const allowLimiter = { limit: async () => ({ success: true }) };

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

test("rejects a conversation that starts with a model message or has unmatched turns", async () => {
  const invalidBodies = [
    { messages: [{ role: "model", text: "سلام" }] },
    { messages: [{ role: "user", text: "سلام" }, { role: "user", text: "پرسش دوم" }] },
    { messages: [{ role: "user", text: "سلام" }, { role: "model", text: "پاسخ" }] },
  ];
  for (const body of invalidBodies) {
    const response = await worker.fetch(makeRequest({ body }), { GEMINI_API_KEY: "test" });
    assert.equal(response.status, 400);
  }
});

test("returns a clear configuration error when the API key is missing", async () => {
  const response = await worker.fetch(makeRequest({ body: validBody }), {});
  assert.equal(response.status, 503);
});

test("fails closed when the rate limiter binding is missing", async () => {
  let called = false;
  globalThis.fetch = async () => {
    called = true;
    throw new Error("Gemini must not be called");
  };
  const response = await worker.fetch(makeRequest({ body: validBody }), {
    GEMINI_API_KEY: "test-key",
  });
  assert.equal(response.status, 503);
  assert.equal(called, false);
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

  const response = await worker.fetch(makeRequest({ body: validBody }), {
    GEMINI_API_KEY: "test-key",
    CHAT_LIMITER: allowLimiter,
  });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).answer, "عدد گویا را می‌توان به شکل کسر نوشت.");
  assert.equal(capturedUrl, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent");
  assert.equal(capturedInit.headers["x-goog-api-key"], "test-key");
  assert.equal(JSON.parse(capturedInit.body).contents[0].role, "user");
});

test("forwards selected study context as untrusted educational reference", async () => {
  let capturedPayload;
  globalThis.fetch = async (_url, init) => {
    capturedPayload = JSON.parse(init.body);
    return new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: "پاسخ آموزشی" }] } }],
    }), { status: 200, headers: { "content-type": "application/json" } });
  };

  const response = await worker.fetch(makeRequest({
    body: {
      ...validBody,
      studyContext: {
        subjectTitle: "ریاضی",
        chapterTitle: "عددهای صحیح و گویا",
        bookChapterTitle: "عددهای صحیح و گویا",
        bookScope: "فصل اول ریاضی",
        alignmentStatus: "not_verified_against_1405_1406_pdf",
        summary: "عددهای گویا به صورت کسر نوشته می‌شوند.",
        sourceLabel: "محتوای اولیهٔ فهمینو",
        points: ["مخرج کسر نباید صفر باشد."],
      },
    },
  }), { GEMINI_API_KEY: "test-key", CHAT_LIMITER: allowLimiter });

  assert.equal(response.status, 200);
  const instruction = capturedPayload.systemInstruction.parts[0].text;
  assert.match(instruction, /عددهای صحیح و گویا/);
  assert.match(instruction, /دستور اجرایی نیست/);
  assert.match(instruction, /محتوای اولیهٔ فهمینو/);
  assert.match(instruction, /not_verified_against_1405_1406_pdf/);
  assert.match(instruction, /تأییدشده یا عین پاسخ کتاب معرفی نکن/);
  assert.match(instruction, /فصل اول ریاضی/);
});

test("rejects oversized or malformed study context", async () => {
  for (const studyContext of [
    "not-an-object",
    { summary: "x".repeat(1201) },
    { points: ["x".repeat(401)] },
    { points: Array.from({ length: 9 }, () => "نکته") },
  ]) {
    const response = await worker.fetch(makeRequest({
      body: { ...validBody, studyContext },
    }), { GEMINI_API_KEY: "test-key" });
    assert.equal(response.status, 400);
  }
});

test("maps Gemini quota responses to HTTP 429", async () => {
  globalThis.fetch = async () => new Response(JSON.stringify({ error: { message: "quota" } }), { status: 429 });
  const response = await worker.fetch(makeRequest({ body: validBody }), {
    GEMINI_API_KEY: "test-key",
    CHAT_LIMITER: allowLimiter,
  });
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

test("returns a controlled error if the rate limiter itself fails", async () => {
  const response = await worker.fetch(makeRequest({ body: validBody }), {
    GEMINI_API_KEY: "test-key",
    CHAT_LIMITER: { limit: async () => { throw new Error("binding unavailable"); } },
  });
  assert.equal(response.status, 503);
});

test("rejects more than 12 messages and messages longer than 3000 characters", async () => {
  const tooMany = { messages: Array.from({ length: 13 }, (_, i) => ({ role: i % 2 ? "model" : "user", text: "سلام" })) };
  const tooLong = { messages: [{ role: "user", text: "ا".repeat(3001) }] };
  for (const body of [tooMany, tooLong]) {
    const response = await worker.fetch(makeRequest({ body }), { GEMINI_API_KEY: "test-key" });
    assert.equal(response.status, 400);
  }
});

test("rejects oversized request bodies", async () => {
  const response = await worker.fetch(makeRequest({
    body: " ".repeat(100_001),
    headers: { "content-type": "application/json" },
  }), { GEMINI_API_KEY: "test-key" });
  assert.equal(response.status, 413);
});

test("maps non-quota Gemini failures to a generic 502 without leaking provider details", async () => {
  globalThis.fetch = async () => new Response(JSON.stringify({
    error: { message: "sensitive upstream diagnostic" },
  }), { status: 500 });
  const response = await worker.fetch(makeRequest({ body: validBody }), {
    GEMINI_API_KEY: "test-key",
    CHAT_LIMITER: allowLimiter,
  });
  assert.equal(response.status, 502);
  const body = await response.json();
  assert.match(body.error, /سرویس هوش مصنوعی/);
  assert.doesNotMatch(body.error, /sensitive upstream diagnostic/);
});

test("returns a controlled error when Gemini has no text candidate", async () => {
  globalThis.fetch = async () => new Response(JSON.stringify({ candidates: [] }), { status: 200 });
  const response = await worker.fetch(makeRequest({ body: validBody }), {
    GEMINI_API_KEY: "test-key",
    CHAT_LIMITER: allowLimiter,
  });
  assert.equal(response.status, 502);
  assert.match((await response.json()).error, /پاسخ متنی/);
});

test("returns a controlled error when Gemini responds with non-JSON content", async () => {
  globalThis.fetch = async () => new Response("upstream unavailable", { status: 502 });
  const response = await worker.fetch(makeRequest({ body: validBody }), {
    GEMINI_API_KEY: "test-key",
    CHAT_LIMITER: allowLimiter,
  });
  assert.equal(response.status, 502);
  assert.match((await response.json()).error, /قابل خواندن نیست/);
});
