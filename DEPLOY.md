# Publicar no GitHub Pages

## Arquivos do site

Envie os arquivos da página, `assets/`, `supabase/`, `conversor.html` e `conversor.js`. O `.gitignore` exclui `Baianos.docx` e `Baianos-importacao.txt`, que são arquivos de trabalho e não fazem parte do site público.

## Publicação automática

O fluxo `.github/workflows/pages.yml` publica o conteúdo da raiz sempre que houver um envio para a branch `main`.

1. Crie um repositório público no GitHub.
2. Envie o conteúdo deste projeto para a branch `main`.
3. Em **Settings → Pages**, escolha **GitHub Actions** como fonte de publicação.
4. Aguarde a execução de **Publish static site to GitHub Pages** na aba **Actions**. O endereço do site aparece na seção **Settings → Pages**.
5. No painel do Supabase, em **Authentication → URL Configuration**, configure esse endereço como **Site URL** e adicione-o às URLs de redirecionamento.
6. Abra o site em uma janela anônima e confira o catálogo; entre na área de administrador para conferir o login.

`supabase-config.js` contém a chave pública publishable, que pode estar no navegador. Nunca substitua essa chave por uma chave `secret` ou `service_role`.
