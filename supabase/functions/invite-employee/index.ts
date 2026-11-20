import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) return new Response(JSON.stringify({ error: "Missing bearer token" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });

    const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: caller, error: authError } = await userClient.auth.getUser();
    if (authError || !caller.user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...cors, "Content-Type": "application/json" } });

    const adminClient = createClient(url, serviceKey);
    const { data: adminRecord, error: adminError } = await adminClient.from("admin_users").select("role").eq("user_id", caller.user.id).maybeSingle();
    if (adminError || adminRecord?.role !== "admin") return new Response(JSON.stringify({ error: "Admins only" }), { status: 403, headers: { ...cors, "Content-Type": "application/json" } });

    const body = await req.json();
    const email = String(body.email || "").trim().toLowerCase();
    const displayName = String(body.display_name || "").trim();
    const roleKey = String(body.role_key || "sales").trim();
    const allowedRoles = ["sales", "marketing", "support", "manager"];
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !displayName || !allowedRoles.includes(roleKey)) {
      return new Response(JSON.stringify({ error: "Invalid email, name, or employee role" }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    }

    const { data: invited, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, { data: { display_name: displayName, account_type: "employee", role_key: roleKey } });
    if (inviteError) return new Response(JSON.stringify({ error: inviteError.message }), { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
    const { error: profileError } = await adminClient.from("platform_profiles").upsert({ user_id: invited.user.id, display_name: displayName, account_type: "employee", role_key: roleKey, active: true });
    if (profileError) return new Response(JSON.stringify({ error: "Invitation sent but profile save failed: " + profileError.message }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
    return new Response(JSON.stringify({ invited: true, user_id: invited.user.id }), { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e?.message || "Unexpected error" }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
