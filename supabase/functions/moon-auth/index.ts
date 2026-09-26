import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseURL = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const admin = createClient(supabaseURL, serviceRoleKey);
const authClient = createClient(supabaseURL, anonKey);

type RequestBody = {
  action: "login" | "register" | "validate-key";
  username: string;
  password: string;
  key: string;
  device_id?: string;
  phone?: string;
};

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeUsername(value: string) {
  return value.trim().toLowerCase();
}

async function hashClientAddress(request: Request) {
  const address =
    request.headers.get("cf-connecting-ip")?.trim() ||
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    "unknown";
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(address));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function hasTooManyFailedAttempts(addressHash: string) {
  const retentionCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { error: pruneError } = await admin
    .from("license_login_attempts")
    .delete()
    .eq("client_ip_hash", addressHash)
    .lt("attempted_at", retentionCutoff);
  if (pruneError) throw pruneError;

  const cutoff = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  const { count, error } = await admin
    .from("license_login_attempts")
    .select("id", { count: "exact", head: true })
    .eq("client_ip_hash", addressHash)
    .gte("attempted_at", cutoff);
  if (error) throw error;
  return (count ?? 0) >= 5;
}

async function recordFailedAttempt(addressHash: string) {
  const { error } = await admin.from("license_login_attempts").insert({
    client_ip_hash: addressHash,
  });
  if (error) throw error;
}

async function rejectKeyAttempt(addressHash: string, message: string, status = 403) {
  try {
    await recordFailedAttempt(addressHash);
  } catch {
    return response({ message: "No se pudo registrar el intento. Inténtalo de nuevo." }, 500);
  }
  return response({ message }, status);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ message: "Method not allowed" }, 405);

  try {
    const body = await request.json() as RequestBody;
    if (
      body.action !== "login" &&
      body.action !== "register" &&
      body.action !== "validate-key"
    ) {
      return response({ message: "Acción no válida." }, 400);
    }
    const username = normalizeUsername(body.username ?? "");
    const password = body.password ?? "";
    const key = body.key?.trim() ?? "";
    const phone = body.phone?.trim() ?? "";

    if (body.action === "validate-key") {
      const deviceID = body.device_id?.trim() ?? "";
      const addressHash = await hashClientAddress(request);
      let rateLimited: boolean;
      try {
        rateLimited = await hasTooManyFailedAttempts(addressHash);
      } catch {
        return response({ message: "El servicio de licencias no está disponible." }, 500);
      }
      if (rateLimited) {
        return response({ message: "Demasiados intentos. Espera unos minutos y vuelve a probar." }, 429);
      }
      if (key.length < 4 || !deviceID) {
        return await rejectKeyAttempt(addressHash, "Pega una key válida para continuar.", 400);
      }

      const { data: license, error: licenseError } = await admin
        .from("licenses")
        .select("id, expires_at, is_active, device_id")
        .eq("license_key", key)
        .maybeSingle();

      if (licenseError) return response({ message: "No se pudo consultar la licencia." }, 500);
      if (!license || !license.is_active || new Date(license.expires_at).getTime() <= Date.now()) {
        return await rejectKeyAttempt(addressHash, "La key no existe, está desactivada o venció.");
      }
      if (license.device_id && license.device_id !== deviceID) {
        return await rejectKeyAttempt(addressHash, "Esta key ya está vinculada a otro dispositivo.");
      }

      if (!license.device_id) {
        const { data: claimed, error: claimError } = await admin
          .from("licenses")
          .update({ device_id: deviceID, activated_at: new Date().toISOString() })
          .eq("id", license.id)
          .is("device_id", null)
          .select("device_id")
          .maybeSingle();
        if (claimError) return response({ message: "No se pudo activar la licencia." }, 500);

        if (!claimed) {
          const { data: current, error: currentError } = await admin
            .from("licenses")
            .select("device_id")
            .eq("id", license.id)
            .maybeSingle();
          if (currentError) return response({ message: "No se pudo confirmar la activación." }, 500);
          if (current?.device_id !== deviceID) {
            return await rejectKeyAttempt(addressHash, "Esta key ya está vinculada a otro dispositivo.");
          }
        }
      }

      return response({
        valid: true,
        expires_at: license.expires_at,
        permanent: license.expires_at === null,
      });
    }

    if (!/^[a-z0-9_.-]{3,32}$/.test(username) || password.length < 6 || key.length < 4) {
      return response({ message: "Invalid username, password or license key" }, 400);
    }

    const { data: license, error: licenseError } = await admin
      .from("licenses")
      .select("id, expires_at, is_active, user_id")
      .eq("license_key", key)
      .maybeSingle();

    if (licenseError) return response({ message: "License lookup failed" }, 500);
    if (!license || !license.is_active || new Date(license.expires_at) <= new Date()) {
      return response({ message: "License is invalid, inactive or expired" }, 403);
    }

    const email = `${username}@moonplace.invalid`;
    let userId = license.user_id;

    if (body.action === "register") {
      if (userId) return response({ message: "License has already been used" }, 409);

      const { data: existing } = await admin
        .from("profiles")
        .select("id")
        .eq("username", username)
        .maybeSingle();
      if (existing) return response({ message: "Username already exists" }, 409);

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { username },
      });
      if (createError || !created.user) return response({ message: createError?.message ?? "User creation failed" }, 400);
      userId = created.user.id;

      const { error: profileError } = await admin.from("profiles").insert({
        id: userId,
        username,
        phone,
        expires_at: license.expires_at,
        is_active: true,
      });
      if (profileError) {
        await admin.auth.admin.deleteUser(userId);
        return response({ message: "Profile creation failed" }, 500);
      }

      const { error: claimError } = await admin
        .from("licenses")
        .update({ user_id: userId })
        .eq("id", license.id)
        .is("user_id", null);
      if (claimError) return response({ message: "License claim failed" }, 500);
    }

    if (body.action === "login" && !userId) {
      return response({ message: "Account is not registered" }, 401);
    }

    const { data: signedIn, error: signInError } = await authClient.auth.signInWithPassword({ email, password });
    if (signInError || !signedIn.session || !userId) {
      return response({ message: signInError?.message ?? "Login failed" }, 401);
    }

    return response({
      access_token: signedIn.session.access_token,
      refresh_token: signedIn.session.refresh_token,
      username,
      phone,
      expires_at: license.expires_at,
    });
  } catch {
    return response({ message: "Malformed request" }, 400);
  }
});
