import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(async (req) => {
  try {
    const body = await req.text(); // on forward tel quel
    const auth = req.headers.get("Authorization") ?? "";
    const contentType = req.headers.get("Content-Type") ?? "application/json";

    // Reconstruit l’URL vers la v2
    const url = new URL(req.url);
    const projectRef = url.host.split(".")[0]; // qfvogtbdqotbvmpxalwx
    const target = `https://${projectRef}.supabase.co/functions/v1/send_push_from_outbox2`;

    // Forward vers outbox2 en conservant l’auth
    const r = await fetch(target, {
      method: "POST",
      headers: {
        "Content-Type": contentType,
        ...(auth ? { "Authorization": auth, "apikey": auth.replace(/^Bearer\s+/i, "") } : {}),
      },
      body,
    });

    const txt = await r.text();
    return new Response(txt, { status: r.status, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e?.message || e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
