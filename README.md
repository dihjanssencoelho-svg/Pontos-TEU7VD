# Pontos TU7VD — caderno de estudo

Site estático, simples e compatível com GitHub Pages. O catálogo público pode ser consultado sem conta. As alterações feitas na área de administração são gravadas no Supabase e protegidas por autenticação e políticas do banco.

## Ativar a área de administração

1. Crie um projeto no Supabase.
2. Abra `supabase/schema.sql` no SQL Editor do projeto e execute o conteúdo para criar a tabela e as políticas de acesso.
3. Em Authentication, crie o usuário administrador. Desative a criação pública de contas se o app será usado somente pelos administradores do templo.
4. No SQL Editor, atribua a função de administrador à conta (troque o e-mail pelo cadastrado):

   ```sql
   update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
   where email = 'admin@exemplo.com';
   ```

5. Copie a Project URL e a chave `anon`/publishable do Supabase para `supabase-config.js`. Essa chave pública foi feita para uso no navegador; nunca coloque a chave `service_role` nesse arquivo.
6. Em Supabase Authentication → URL Configuration, configure a URL publicada no GitHub Pages como Site URL e redirect permitido.
7. Publique os arquivos deste projeto no repositório e ative GitHub Pages.

O app só libera edição se a sessão autenticada tiver `app_metadata.role = admin`. A tabela usa Row Level Security: qualquer visitante pode ler, mas somente administradores podem inserir ou alterar pontos. Senhas não são armazenadas no código do site.

## Uso

- O administrador entra pela aba **Administrador** com e-mail e senha.
- Pode selecionar um ponto, alterar nome, categoria, grupo, link e letra, ou criar um novo ponto.
- **Salvar alterações** atualiza o catálogo compartilhado no Supabase.
- **Baixar letra .txt** salva a letra aberta; **Baixar letras .txt** salva o catálogo inteiro em um arquivo de texto.
- **Exportar catálogo** gera uma cópia JSON para backup.
- Visitantes veem as letras em modo de leitura e podem baixar o TXT.

O código e os arquivos visuais permanecem no GitHub. Os dados editáveis ficam no Supabase para que o administrador possa atualizar o conteúdo pela página sem expor senha ou token de escrita no repositório. A lista inicial continua no `app.js` e serve de catálogo base.
