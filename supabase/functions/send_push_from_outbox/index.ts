// supabase/functions/send_push_from_outbox/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts";

// Supabase (service role)
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

// FCM v1 credentials (depuis secrets)
const PROJECT_ID = Deno.env.get("FCM_PROJECT_ID")!;
const CLIENT_EMAIL = Deno.env.get("FCM_CLIENT_EMAIL")!;
// ⚠️ convertir les \n littéraux en vrais retours à la ligne
const PRIVATE_KEY = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");

// Génère un access token OAuth2 pour FCM v1
async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: CLIENT_EMAIL,
    sub: CLIENT_EMAIL,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const jwt = await new jose.SignJWT(payload)
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .sign(await jose.importPKCS8(PRIVATE_KEY, "RS256"));

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const json = await res.json();
  if (!json.access_token) {
    throw new Error("Failed to get access token: " + JSON.stringify(json));
  }
  return json.access_token as string;
}

Deno.serve(async (req) => {
  try {
    const { outbox_id } = await req.json();
    if (!outbox_id) {
      return new Response(JSON.stringify({ error: "Missing outbox_id" }), { status: 400 });
    }

    // 1) Lire la notification (⚠️ table correcte)
    const { data: outbox, error: outErr } = await supabase
      .from("notification_outbox")
      .select("*")
      .eq("id", outbox_id)
      .single();

    if (outErr || !outbox) {
      console.error("Outbox not found:", outErr);
      return new Response(JSON.stringify({ error: "Outbox not found" }), { status: 404 });
    }

    // 2) Récupérer les devices (⚠️ table correcte)
    const { data: devices, error: devErr } = await supabase
      .from("user_devices")
      .select("token")
      .eq("revoked", false);

    if (devErr) throw devErr;
    if (!devices || devices.length === 0) {
      await supabase
        .from("notification_outbox")
        .update({ status: "failed", error: "no_devices" })
        .eq("id", outbox_id);
      return new Response(JSON.stringify({ ok: false, reason: "no_devices" }), { status: 200 });
    }

    // 3) Access token FCM v1
    const accessToken = await getAccessToken();
    const url = `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`;

    // 4) Envoi à chaque token (FCM v1 = 1 token par requête)
    const results = await Promise.all(
      devices.map(async (d) => {
        const resp = await fetch(url, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: d.token,
              notification: {
                title: outbox.type ?? "Notification",
                body: outbox.content ?? "",
              },
              data: { outbox_id: String(outbox.id) },
            },
          }),
        });
        const body = await resp.text(); // utile pour les logs
        return { token: d.token, ok: resp.ok, status: resp.status, body };
      })
    );

    const failures = results.filter((r) => !r.ok);
    await supabase
      .from("notification_outbox")
      .update({
        status: failures.length ? "failed" : "sent",
        error: failures.length ? JSON.stringify({ failures }) : null,
      })
      .eq("id", outbox_id);

    return new Response(
      JSON.stringify({
        ok: failures.length === 0,
        outbox_id,
        sent: results.length,
        failures: failures.length,
      }),
      { status: 200 }
    );
  } catch (e) {
    console.error("Unhandled error:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
