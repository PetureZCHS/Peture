import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Strictly use service role for backend data writes.
export const serviceClient = createClient(supabaseUrl, serviceRole);
// Use anon key for token verification to avoid mutating service client auth context.
const authClient = createClient(supabaseUrl, anonKey);

export async function requireUserFromRequest(req: Request): Promise<{ userId: string } | { error: Response }> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : authHeader;
  if (!token) {
    return {
      error: new Response(
        JSON.stringify({
          error: "Missing Authorization header",
          errorCode: "MODERATION_UNAUTHORIZED",
        }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      ),
    };
  }

  const { data, error } = await authClient.auth.getUser(token);
  if (error || !data.user) {
    return {
      error: new Response(
        JSON.stringify({
          error: "Unauthorized",
          errorCode: "MODERATION_UNAUTHORIZED",
        }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      ),
    };
  }

  return { userId: data.user.id };
}

