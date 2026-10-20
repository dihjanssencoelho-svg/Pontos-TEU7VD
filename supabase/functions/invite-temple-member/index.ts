import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://dihjanssencoelho-svg.github.io',
  'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return jsonResponse(405, { error: 'Método não permitido.' });

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return jsonResponse(401, { error: 'Sessão necessária.' });

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SECRET_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error('Supabase environment variables are not configured.');
    return jsonResponse(500, { error: 'Configuração incompleta no Supabase.' });
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data: callerData, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerData.user) return jsonResponse(401, { error: 'Sessão inválida.' });
  if (callerData.user.app_metadata?.role !== 'admin') return jsonResponse(403, { error: 'Somente administradores podem enviar convites.' });

  let email = '';
  try {
    const body = await request.json();
    email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  } catch {
    return jsonResponse(400, { error: 'Informe um e-mail válido.' });
  }
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonResponse(400, { error: 'Informe um e-mail válido.' });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email);
  if (inviteError || !inviteData.user) {
    console.error('Invite failed:', inviteError?.message);
    return jsonResponse(400, { error: 'Não foi possível enviar o convite. O e-mail pode já estar cadastrado.' });
  }

  const appMetadata = { ...inviteData.user.app_metadata, role: 'temple_member' };
  const { error: roleError } = await adminClient.auth.admin.updateUserById(inviteData.user.id, { app_metadata: appMetadata });
  if (roleError) {
    await adminClient.auth.admin.deleteUser(inviteData.user.id);
    console.error('Could not assign admin access:', roleError.message);
    return jsonResponse(500, { error: 'Não foi possível concluir o cadastro.' });
  }

  return jsonResponse(200, { ok: true });
});
