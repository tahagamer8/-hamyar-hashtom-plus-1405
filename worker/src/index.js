const MODEL = "gemini-3.8-flash";
const MAX_MESSAGES = 12;
const MAX_MESSAGE_LENGTH = 3000;
const MAX_OUTPUT_TOKENS = 900;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

function validMessages(messages) {
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > MAX_MESSAGES) return false;
  return messages.every((m) =>
    m && ["user", "model"].includes(m.role) &&
    typeof m.text === "string" &&
    m.text.trim().length > 0 &&
    m.text.length <= MAX_MESSAGE_LENGTH
  );
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/api/chat") {
      return json({ error: "مسیر درخواست پیدا نشد." }, 404);
    }
    if (!env.GEMINI_API_KEY) return json({ error: "کلید سرویس روی سرور تنظیم نشده است." }, 503);

    if (env.CHAT_LIMITER) {
      const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
      const { success } = await env.CHAT_LIMITER.limit({ key: clientIp });
      if (!success) return json({ error: "تعداد درخواست‌ها زیاد است؛ یک دقیقه بعد دوباره امتحان کن." }, 429);
    }

    let body;
    try { body = await request.json(); } catch { return json({ error: "درخواست نامعتبر است." }, 400); }
    if (!body || typeof body !== "object" || !validMessages(body.messages)) {
      return json({ error: "پیام‌ها نامعتبرند یا تعدادشان بیش از حد است." }, 400);
    }

    const contents = body.messages.map((m) => ({
      role: m.role,
      parts: [{ text: m.text.trim() }],
    }));

    const payload = {
      systemInstruction: {
        parts: [{
          text: [
            "تو دستیار آموزشی اپلیکیشن فهمینو برای دانش‌آموز پایه هشتم هستی.",
            "به فارسی روان، دقیق، محترمانه و متناسب با سن دانش‌آموز پاسخ بده.",
            "مفاهیم را مرحله‌به‌مرحله آموزش بده؛ اگر سؤال درسی است ابتدا روش فهمیدن را توضیح بده.",
            "اگر از پاسخ مطمئن نیستی صادقانه بگو و منبع یا صفحه کتاب را جعل نکن.",
            "برای محتوای کتاب، بین اطلاعات قطعی و توضیح تکمیلی تفاوت بگذار.",
            "از درخواست‌های خطرناک، محتوای جنسی، خودآزاری یا خشونت‌آمیزِ عملی پیروی نکن.",
            "پاسخ‌ها را روشن و نسبتاً کوتاه نگه دار و از Markdown ساده استفاده کن."
          ].join("\n")
        }]
      },
      contents,
      generationConfig: {
        temperature: 0.45,
        maxOutputTokens: MAX_OUTPUT_TOKENS,
      },
    };

    try {
      const upstream = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": env.GEMINI_API_KEY,
          },
          body: JSON.stringify(payload),
        }
      );
      const result = await upstream.json();
      if (!upstream.ok) {
        return json({ error: upstream.status === 429
          ? "سهمیهٔ درخواست‌ها فعلاً تمام شده؛ کمی بعد دوباره امتحان کن."
          : "ارتباط با سرویس هوش مصنوعی برقرار نشد. تنظیمات سرور را بررسی کن." }, upstream.status === 429 ? 429 : 502);
      }
      const answer = result.candidates?.[0]?.content?.parts
        ?.map((part) => part.text || "")
        .join("")
        .trim();
      if (!answer) return json({ error: "پاسخ متنی دریافت نشد؛ سؤال را دوباره بفرست." }, 502);
      return json({ answer });
    } catch {
      return json({ error: "خطای ارتباطی رخ داد. اتصال اینترنت را بررسی کن." }, 502);
    }
  },
};
