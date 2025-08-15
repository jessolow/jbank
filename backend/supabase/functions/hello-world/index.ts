import { serve } from "https://deno.land/std@0.131.0/http/server.ts";

serve((req) => {
  return new Response(JSON.stringify({ message: "Hello from Supabase Edge Function" }), {
    headers: { "Content-Type": "application/json" },
  });
});
