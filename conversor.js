const fileInput=document.querySelector('#files');
const categoryInput=document.querySelector('#category');
const groupInput=document.querySelector('#group');
const output=document.querySelector('#output');
const status=document.querySelector('#status');
const summary=document.querySelector('#summary');
const downloadButton=document.querySelector('#download');

function decodeText(buffer){try{return new TextDecoder('utf-8',{fatal:true}).decode(buffer);}catch{return new TextDecoder('windows-1252').decode(buffer);}}
async function readFile(file){
  if(file.name.toLowerCase().endsWith('.txt'))return decodeText(await file.arrayBuffer()).replace(/^\uFEFF/,'');
  if(!file.name.toLowerCase().endsWith('.docx'))throw new Error(`${file.name}: formato não suportado.`);
  if(!window.JSZip)throw new Error('Não consegui carregar o leitor de DOCX. Confira a conexão e tente novamente.');
  const zip=await JSZip.loadAsync(file);const doc=zip.file('word/document.xml');
  if(!doc)throw new Error(`${file.name}: o documento Word está inválido.`);
  const xml=new DOMParser().parseFromString(await doc.async('text'),'application/xml');
  if(xml.querySelector('parsererror'))throw new Error(`${file.name}: não foi possível ler o conteúdo DOCX.`);
  const ns='http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  return [...xml.getElementsByTagNameNS(ns,'p')].map(p=>[...p.childNodes].map(node=>{
    if(node.nodeType!==1)return '';
    if(node.localName==='r')return [...node.getElementsByTagNameNS(ns,'t')].map(t=>t.textContent||'').join('')||[...node.getElementsByTagNameNS(ns,'tab')].map(()=> '\t').join('');
    if(node.localName==='hyperlink')return [...node.getElementsByTagNameNS(ns,'t')].map(t=>t.textContent||'').join('');
    return '';
  }).join('')).join('\n');
}
function splitBlocks(text){
  const normalized=text.replace(/\r\n?/g,'\n').replace(/\u00a0/g,' ');
  const blocks=normalized.split(/^\s*(?:[-_=*]{3,}|\*\s+\*\s+\*)\s*$/m).map(b=>b.trim()).filter(Boolean);
  return blocks.length?blocks:[normalized.trim()].filter(Boolean);
}
function cleanTitle(line){return line.replace(/^\s*(?:\d{1,3}[.)-]|[•●▪-])\s*/,'').replace(/\s+/g,' ').trim().replace(/:$/,'');}
function escapeField(value){return String(value||'').replace(/[\r\n]+/g,' ').trim();}
function pointsFromFile(text,file,defaultCategory,group){
  const blocks=splitBlocks(text);const category=defaultCategory||file.name.replace(/\.[^.]+$/,'').replace(/[_-]+/g,' ').trim()||'Importados';
  const records=[];
  for(const block of blocks){
    const lines=block.split('\n');const first=lines.findIndex(line=>line.trim());if(first<0)continue;
    const content=lines.slice(first).map(line=>line.trimEnd());
    const title=cleanTitle(content[0]);const lyrics=content.slice(1).join('\n').trim();
    if(!title||!lyrics)continue;
    records.push({title,category,group,lyrics});
  }
  return records;
}
function formatRecords(records){return records.map(p=>`Ponto: ${escapeField(p.title)}\nCategoria: ${escapeField(p.category)}\nGrupo: ${p.group}\nLetra:\n${p.lyrics.trim()}`).join('\n---\n');}
function normalize(value){return String(value).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('pt-BR').replace(/[^a-z0-9]+/g,' ').trim();}

document.querySelector('#convert').addEventListener('click',async()=>{
  const files=[...fileInput.files];status.classList.remove('error');downloadButton.disabled=true;
  if(!files.length){status.textContent='Selecione um ou mais arquivos primeiro.';status.classList.add('error');return;}
  status.textContent='Lendo e convertendo…';summary.textContent='';output.value='';
  try{
    const records=[];const skipped=[];
    for(const file of files){const parsed=pointsFromFile(await readFile(file),file,categoryInput.value.trim(),groupInput.value);if(!parsed.length)skipped.push(file.name);records.push(...parsed);}
    if(!records.length)throw new Error('Não encontrei pontos completos. Cada bloco precisa ter um título na primeira linha e a letra nas linhas seguintes.');
    output.value=formatRecords(records);const counts=new Map();for(const p of records){const key=normalize(p.title);counts.set(key,(counts.get(key)||0)+1);}const duplicates=[...counts.values()].filter(n=>n>1).length;
    summary.textContent=`${records.length} ponto(s) reconhecido(s) em ${files.length} arquivo(s).${duplicates?` Há ${duplicates} título(s) repetido(s); confira na prévia e na importação.`:''}${skipped.length?` Sem pontos reconhecidos: ${skipped.join(', ')}.`:''}`;
    status.textContent='Conversão concluída. Revise a prévia e baixe o arquivo para importar.';downloadButton.disabled=false;
  }catch(error){status.textContent=error.message||'Falha ao converter os arquivos.';status.classList.add('error');}
});
downloadButton.addEventListener('click',()=>{
  const content=output.value.trim();if(!content)return;const blob=new Blob(['\uFEFF',content],{type:'text/plain;charset=utf-8'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='pontos-para-importacao.txt';a.click();URL.revokeObjectURL(url);
});
