import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

Deno.serve(async (req) => {
  try {
    const { outbox_id } = await req.json();
    if (!outbox_id) {
      return new Response(
        JSON.stringify({ error: "Missing outbox_id" }),
        { status: 400 }
      );
    }

    // Récupérer la notif
    const { data: row, error } = await supabase
      .from("notification_outbox")
      .select("*")
      .eq("id", outbox_id)
      .single();

    if (error || !row) {
      return new Response(
        JSON.stringify({ error: "Outbox not found", details: error }),
        { status: 404 }
      );
    }

    // ✅ PATCH sur filters
    let filters: any = {};
    try {
      if (typeof row.filters === "string") {
        // Si c’est une chaîne → tenter base64 puis JSON direct
        try {
          filters = JSON.parse(atob(row.filters));
        } catch {
          filters = JSON.parse(row.filters);
        }
      } else {
        // Si c’est un objet (jsonb)
        filters = row.filters;
      }
    } catch (_e) {
      filters = {};
    }

    console.log("Filters décodés =", filters);

    // TODO: ici tu ajoutes l’envoi FCM avec row.content, row.type, row.attachment_url, filters

    return new Response(
      JSON.stringify({ ok: true, outbox_id, filters }),
      { status: 200 }
    );
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ error: e.message ?? String(e) }),
      { status: 500 }
    );
  }
});
