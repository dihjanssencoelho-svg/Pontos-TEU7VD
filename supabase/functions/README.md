# Convites de acesso do templo

O administrador principal pode enviar convites pela área Administrador do site. A pessoa recebe um link por e-mail e define a própria senha. A conta recebe o papel `temple_member`: pode entrar e editar o catálogo, mas não pode convidar outras pessoas. Só uma conta com papel `admin` pode enviar convites.

## Preparação única

1. Execute novamente `supabase/schema.sql` no SQL Editor do projeto para permitir que contas `temple_member` editem o catálogo.
2. No GitHub, abra **Settings → Secrets and variables → Actions** e crie o segredo `SUPABASE_ACCESS_TOKEN`. Use um token do Supabase com permissão para implantar Edge Functions; nunca coloque esse token no código do site ou neste repositório.
3. Depois de salvar o segredo, abra **Actions → Deploy Supabase invite function → Run workflow** para implantar `invite-temple-member`. Atualizações futuras desta função serão implantadas automaticamente quando forem enviadas para `main`.
4. Em **Supabase → Authentication → URL Configuration**, confirme que `https://dihjanssencoelho-svg.github.io/Pontos-TEU7VD/` é a URL do site e está entre os redirecionamentos permitidos.
5. Desative o cadastro público de usuários em **Authentication → Sign In / Providers → Email**. Os convites administrativos continuam sendo enviados pelo servidor.

Para entregar convites a e-mails fora da equipe da organização Supabase, configure um SMTP próprio em **Authentication → Emails → SMTP Settings**. O serviço SMTP padrão só envia para endereços autorizados da equipe e tem limite reduzido; consulte a [documentação de SMTP do Supabase](https://supabase.com/docs/guides/auth/auth-smtp).

O navegador chama a Edge Function com a sessão autenticada. A função valida que quem convida tem `app_metadata.role = admin` e usa a chave secreta apenas no servidor. Nunca copie uma chave `secret` ou `service_role` para `supabase-config.js`.
