const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders });
}

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        ok: true,
        service: "fahmino-api-2",
        mode: "offline",
        externalAiEnabled: false,
      });
    }

    if (request.method === "POST" && url.pathname === "/api/chat") {
      return json({
        error: "دستیار ابری در فهمینو فعال نیست؛ از راهنمای آفلاین داخل برنامه استفاده کن.",
      }, 410);
    }

    return json({ error: "مسیر درخواست پیدا نشد." }, 404);
  },
};
