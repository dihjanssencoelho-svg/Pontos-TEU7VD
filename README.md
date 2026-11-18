
# Pontos TU7VD — caderno de estudo

Site estático, simples e compatível com GitHub Pages. O catálogo público pode ser consultado sem conta. As alterações feitas na área de administração são gravadas no Supabase e protegidas por autenticação e políticas do banco.

## Ativar a área de administração

1. Crie um projeto no Supabase.
2. Abra `supabase/schema.sql` no SQL Editor do projeto e execute o conteúdo para criar a tabela e as políticas de acesso.
3. Em **Authentication**, crie o usuário administrador. Desative a criação pública de contas caso o app seja usado somente pelos administradores do templo.
4. No SQL Editor, atribua a função de administrador à conta (troque o e-mail pelo cadastrado):

   ```sql
   update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
   where email = 'admin@exemplo.com';
   ```

5. Copie a URL do projeto e a chave `anon` ou `publishable` do Supabase para `supabase-config.js`. Essa chave pública foi feita para uso no navegador; nunca coloque a chave `service_role` nesse arquivo.
6. Em **Authentication → URL Configuration**, configure o endereço publicado no GitHub Pages como **Site URL** e adicione-o às URLs de redirecionamento permitidas.
7. Publique os arquivos deste projeto no repositório e ative GitHub Pages.

O app só libera edição se a sessão autenticada tiver `app_metadata.role = admin`. A tabela usa Row Level Security: qualquer visitante pode ler, mas somente administradores podem inserir ou alterar pontos. Senhas não são armazenadas no código do site.

## Uso

- O administrador entra pela aba **Administrador** com e-mail e senha.
- Pode selecionar um ponto, alterar o nome, a categoria, o grupo, os links e a letra, ou criar um novo ponto.
- **Salvar alterações** atualiza o catálogo compartilhado no Supabase.
- **Baixar letra .txt** salva a letra aberta; **Baixar letras .txt** salva o catálogo inteiro em um arquivo de texto.
- **Exportar catálogo** gera uma cópia JSON para backup.
- Visitantes veem as letras em modo de leitura e podem baixar o TXT.

O código e os arquivos visuais permanecem no GitHub. Os dados editáveis ficam no Supabase para que o administrador possa atualizar o conteúdo pela página sem expor senha ou token de escrita no repositório. A lista inicial continua no `app.js` e serve de catálogo base.


O catálogo do [TUEG](https://pontos-cantados.tueg.pt/) também pode ser consultado como referência. Áudio direto cadastrado em MP3, OGG ou WAV é reproduzido no player da página. Vídeos do YouTube podem ser exibidos no mini player ou na janela do ponto; links do Spotify ficam como referência.


Quando o administrador cadastra uma URL de vídeo do YouTube no ponto, a página incorpora o player oficial junto à letra e também pode reproduzi-lo no mini player do rodapé.

## Reprodução em sequência

Ao abrir um card, a janela do ponto mostra sua letra e vídeo/áudio para reprodução direta. O botão **Ouvir no player** inicia a mídia no player fixo do rodapé, sem fechar o detalhe; assim a pessoa escolhe onde ouvir. No player, vídeos do YouTube aparecem em miniatura e áudios diretos usam os controles próprios. **Mostrar letra** abre um painel sobre a página e mantém a reprodução ativa; o convite desaparece enquanto a letra está aberta e reaparece quando ela é fechada. Ao avançar de faixa, o painel acompanha a letra do ponto atual. O seletor oferece faixas disponíveis na categoria, linha de trabalho, fila personalizada ou em todos os pontos publicados. Ao terminar uma faixa de áudio ou vídeo, o player avança para a próxima faixa disponível. Itens removidos, rascunhos, pontos sem mídia e links do Spotify não entram nas filas. Em celulares, deslize horizontalmente sobre o título para avançar ou voltar.


## Grupo Ritualística

O catálogo também permite cadastrar pontos no grupo **Ritualística**, com os subgrupos **Defumação** e **Abertura**. Na edição do ponto, selecione `Ritualística` em **Grupo** e escolha o subgrupo correspondente. Os pontos anteriores permanecem nas categorias e grupos originais.

Para bancos já existentes, aplique uma única vez a migração `supabase/migrations/20261113_ritualistica_grupo.sql` no SQL Editor do Supabase. Ela apenas amplia a restrição `work_group`; não altera nem exclui registros. O arquivo `supabase/schema.sql` também foi atualizado para novas instalações.

## Revisão textual de novos pontos e edições

Em projetos existentes, aplique as migrações de revisão em ordem depois do esquema atual, finalize com `supabase/migrations/20261118145523_add_point_catalog_history.sql` e depois aplique as migrações `supabase/migrations/20261118163220_add_public_point_suggestions.sql` e `supabase/migrations/20261118163900_harden_point_suggestion_audio.sql`. Em uma instalação nova, execute primeiro `supabase/schema.sql` e depois as migrações `supabase/migrations/20261116124408_add_point_text_review_workflow.sql`, `supabase/migrations/20261116125157_lock_point_writes_to_review_rpcs.sql`, `supabase/migrations/20261116133149_approve_point_text_review_suggestions.sql`, `supabase/migrations/20261116163537_apply_refreshed_review_suggestions.sql`, `supabase/migrations/20261118145523_add_point_catalog_history.sql`, `supabase/migrations/20261118163220_add_public_point_suggestions.sql` e `supabase/migrations/20261118163900_harden_point_suggestion_audio.sql`, nessa ordem. A migração de histórico cria uma trilha privada de alterações, copia aprovações anteriores e registra inclusões, edições e exclusões futuras; ela não altera os pontos nem a tabela de backup.

## Indique seu Ponto

Visitantes podem enviar uma indicação de ponto com nome opcional, grupo, Orixá/linha, letra, link do YouTube opcional e gravação de voz opcional de até 15 MB. As indicações ficam fora do catálogo publicado e só podem ser consultadas pela equipe autenticada do templo. As gravações ficam em um bucket privado do Supabase Storage; a equipe pode ouvir a gravação na área Administrador. A migração do formulário e a migração seguinte restringem o caminho da gravação ao identificador único da indicação.

Depois das migrações do formulário, aplique `supabase/migrations/20261118180000_moderate_point_suggestions.sql`. A pessoa recebe uma confirmação agradecendo e explicando que a inclusão depende da aprovação dos dirigentes. Antes de enviar, a página compara título e letra com o catálogo ativo e informa o ponto e a categoria quando encontra correspondência. A equipe pode consultar todas as indicações; somente usuários com `app_metadata.role = 'admin'` veem e podem usar as ações de aprovar ou rejeitar. A aprovação insere o ponto no catálogo e registra a decisão; uma checagem adicional evita publicar duplicatas que tenham surgido depois do envio.

Para aplicar melhorias de catálogo, filtros, listas pessoais, busca administrativa e motivo obrigatório de rejeição, aplique também `supabase/migrations/20261118172941_add_rejection_reason_to_point_suggestions.sql`. Essa atualização registra o motivo no campo de histórico já existente e não altera pontos, letras ou mídias.

No catálogo, a busca sugere pontos enquanto a pessoa digita e destaca ocorrências na letra. Os filtros de categoria, mídia e disponibilidade de letra podem ser combinados. Cada card identifica letra, vídeo e áudio e oferece abrir, ouvir ou salvar em uma lista pessoal. As listas ficam no armazenamento local do navegador e podem ser usadas como fila personalizada do player. O formulário mostra correspondências prováveis durante a digitação; a verificação final contra o catálogo continua antes do envio. Links diretos, cópia e impressão da letra estão disponíveis na ficha do ponto.

Novos pontos e alterações no título, complemento ou letra ficam pendentes até que uma pessoa autorizada aprove ou rejeite a proposta. Quando houver sugestão de capitalização, a ação principal aplica a sugestão e aprova; o texto original, a proposta e o texto aprovado ficam registrados separadamente. Textos em caixa alta, inclusive versos com marcações como `(x2)`, recebem sugestão de caixa de frase. Revisões pendentes aparecem na aba **Revisão pendente**; inclusões aprovadas, edições e exclusões ficam na aba **Histórico**. Enquanto aguarda, o catálogo público continua exibindo o texto aprovado. Alterações apenas em metadados não textuais são imediatas e entram no histórico. A decisão registra o conteúdo original, a proposta, as sugestões automáticas, quem enviou e quem decidiu. As sugestões são locais e gratuitas; versos repetidos e grafias rituais protegidas não são alterados automaticamente.