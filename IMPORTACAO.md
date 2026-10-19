# Importação de pontos

Na área **Administrador**, use **Importar pontos (.txt / .docx)**. A prévia informa se cada ponto é novo, já existe, está sem letra ou tem letra diferente. O app só grava quando você confirma.

## Formato recomendado

Use estes campos para cada ponto e separe os pontos por uma linha com três hífens (`---`):

```text
Ponto: Hino a Oxalá
Categoria: Oxalá
Grupo: Orixás
Fonte: https://exemplo.org/referencia
Vídeo: https://www.youtube.com/watch?v=...
Áudio: https://open.spotify.com/track/...
Letra:
Primeiro verso
Segundo verso

Terceiro verso
---
Ponto: Nome do próximo ponto
Linha: Caboclos
Letra:
Letra do próximo ponto
```

`Fonte`, `Vídeo` e `Áudio` são opcionais. Para um arquivo de um único ponto, também é aceito o título na primeira linha e a letra nas linhas seguintes; nesse formato simples, a categoria será **Importados**.

## Verificação de mídia

Para pontos novos, a prévia oferece buscas no YouTube e no Spotify. Abra os resultados, escolha a gravação correta e cole o endereço no campo de vídeo ou áudio antes de confirmar. A gravação selecionada será exibida como link junto ao ponto. O app não escolhe automaticamente uma gravação porque os resultados dependem da versão e do contexto do templo.

## Atualização do banco

Como a tabela existente agora também armazena URLs de vídeo e áudio, execute novamente `supabase/schema.sql` no SQL Editor do Supabase como `postgres` antes da primeira importação. As instruções adicionam as colunas ausentes sem remover os pontos já cadastrados.


## Converter vários arquivos

Abra `conversor.html` no navegador ou use **Preparar vários arquivos** na área do administrador. Selecione vários arquivos `.docx` e `.txt` de uma vez, escolha o grupo e, opcionalmente, informe uma categoria padrão. Se o campo de categoria ficar vazio, o conversor usará o nome de cada arquivo.

Para reconhecer vários pontos no mesmo documento, separe-os com uma linha de pelo menos três hífens (`---`), sublinhados, sinais de igual ou asteriscos. A primeira linha de cada bloco será o título; as linhas seguintes serão a letra. Sem separadores, o arquivo será interpretado como um único ponto. Confira e edite a prévia antes de baixar `pontos-para-importacao.txt`; depois, importe esse arquivo TXT pela área do administrador.

O conversor organiza o texto, mas não atribui gravações automaticamente. Durante a importação, o site oferece buscas no YouTube e no Spotify para pontos novos. O administrador pode conferir a versão e cadastrar o link escolhido.
