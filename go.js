// go.js: draws the bookmark page (index.html) from go.md: task cards, round script buttons, remembered open state.
// Moved out of index.html (fleet v2, 2026-11-23) so the page's Content-Security-Policy can say script-src 'self' with no
// 'unsafe-inline'. Runs in the browser; tests/check_go_page.js loads it in node with window.GO_TEST set.
// Network: go.md and the round scripts from this repository's branch folder on raw.githubusercontent.com only (the page
// CSP connect-src allows that one source; master plan P4b 2026-11-24). The owner, repo and branch come from the go.js
// script tag in index.html (data-owner, data-repo, data-branch), which tests/check_go_page.js holds equal to site.config.json.
// Writes: this browser's localStorage key go-open-v1 (which cards are open).
// Credentials: none.
'use strict';
var SRC='';   // the go.md URL, built from the script tag values (fleet v2 DEC 7: their home is site.config.json)
var CFG=null; // owner, repo, branch from the script tag
var ME=typeof document!=='undefined'?document.currentScript:null; // this script tag, read while go.js runs (null in node)
var NAME=/^[A-Za-z0-9_.-]+$/; // an owner, repo or branch name: nothing else may enter a URL
/**
 * validCfg(c): true when a config holds safe owner, repo and branch names.
 * @param {object} c the config (from the go.js tag, or the parsed site.config.json in the test).
 * @returns {boolean} true when all three names are safe.
 */
function validCfg(c){return !!c&&typeof c==='object'&&['owner','repo','branch'].every(function(k){return typeof c[k]==='string'&&NAME.test(c[k])})}
/**
 * rawBase(c): the raw.githubusercontent.com folder of the repository branch, ending in /.
 * @param {object} c a config that passed validCfg.
 * @returns {string} the folder URL.
 */
function rawBase(c){return 'https://raw.githubusercontent.com/'+c.owner+'/'+c.repo+'/'+c.branch+'/'}
var KEY='go-open-v1';
/**
 * esc(s): escapes text for HTML (&, <, >, ").
 * @param {*} s the text.
 * @returns {string} the escaped text.
 */
function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')}
/**
 * inl(s): the HTML of one go.md text line: escaped, then links, **bold** and `code`.
 * @param {string} s the line.
 * @returns {string} the HTML.
 */
function inl(s){
  var LINK=/(https?:\/\/[^\s<]+|(?:raw\.githubusercontent\.com|[a-z0-9-]+\.github\.io)\/[^\s<]*)/g;
  var o=esc(s).replace(LINK,function(u){var h=u.indexOf('http')===0?u:'https://'+u;return '<a href="'+h+'" rel="noopener noreferrer">'+u+'</a>'});
  o=o.replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>').replace(/`([^`]+)`/g,'<code>$1</code>');
  return o;
}
/**
 * slug(s, i): a page id for a card.
 * @param {string} s the card name.
 * @param {number} i the card number.
 * @returns {string} the id.
 */
function slug(s,i){return 's'+i+'-'+s.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,40)}
/**
 * validState(o): keeps only the safe part of a stored open-state object: string keys (not __proto__, at most 200
 * characters) with true/false values, in an object with no prototype. Anything else gives an empty state.
 * @param {*} o the parsed stored value.
 * @returns {object} the clean state.
 */
function validState(o){
  var r=Object.create(null);
  if(!o||typeof o!=='object'||Array.isArray(o))return r;
  Object.keys(o).forEach(function(k){if(k!=='__proto__'&&k.length<=200&&typeof o[k]==='boolean')r[k]=o[k]});
  return r;
}
/**
 * load(): reads the remembered open state of this browser.
 * @returns {object} the clean state (validState).
 */
function load(){try{return validState(JSON.parse(localStorage.getItem(KEY)||'{}'))}catch(e){return validState(null)}}
/**
 * save(o): stores the open state in this browser; a blocked storage is ignored.
 * @param {object} o the state.
 */
function save(o){try{localStorage.setItem(KEY,JSON.stringify(o))}catch(e){}}
/**
 * later(b, t, ms): puts the text t back on button b after ms milliseconds.
 * @param {Element} b the button.
 * @param {string} t the text.
 * @param {number} ms the wait.
 */
function later(b,t,ms){
  // the timer callback: set the text back
  setTimeout(function(){b.textContent=t},ms);
}
/**
 * copy(t, b): copies text t to the clipboard and shows "Copied" on button b for a moment.
 * @param {string} t the text.
 * @param {Element} b the button.
 */
function copy(t,b){
  // ok: show the result, then the old label
  var ok=function(){var x=b.textContent;b.textContent='Copied';later(b,x,1200)};
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(ok,function(){fallback(t);ok()})}else{fallback(t);ok()}
}
/**
 * fallback(t): copies text t through a hidden text area (for a browser without the clipboard API).
 * @param {string} t the text.
 * @returns {boolean} true when the browser copied.
 */
function fallback(t){
  var a=document.createElement('textarea'),r=false;
  a.value=t;a.style.position='fixed';a.style.opacity='0';document.body.appendChild(a);a.select();
  try{r=document.execCommand('copy')}catch(e){r=false}
  document.body.removeChild(a);return r;
}
var SCRIPTS={}; // round scripts, loaded ahead so one click copies the whole text (PFM 13 Nov)
/**
 * isRound(h): true for a link to a round script (scripts/gov/paste/*.ps1).
 * @param {string} h the link.
 * @returns {boolean} true for a round script.
 */
function isRound(h){return /\/scripts\/gov\/paste\/[^\/]+\.ps1$/.test(h)}
/**
 * fileCard(u): the HTML of a file card for a bare URL line.
 * @param {string} u the URL (with or without https://).
 * @returns {string} the HTML.
 */
function fileCard(u){
  var h=u.indexOf('http')===0?u:'https://'+u, name=h.split('/').pop();
  // A round script has no .ps1 link and no Copy link (PFM 20 Nov 26): Open as .txt takes the link's place, to read the script before pasting it.
  if(isRound(h))return '<div class="file"><span class="fn"><strong>'+esc(name)+'</strong></span>'+
    '<button type="button" data-txt="'+esc(h)+'" data-label="Open as .txt"'+
    ' aria-label="Open as .txt: save '+esc(txtName(h))+' to read the script before you paste it">Open as .txt</button>'+
    '<button type="button" class="primary" data-script="'+esc(h)+'" aria-label="Copy the whole script '+esc(name)+'">Copy script</button></div>';
  return '<div class="file"><span class="fn"><a href="'+esc(h)+'" rel="noopener noreferrer">'+esc(name)+'</a><span class="fu">'+esc(h)+'</span></span>'+
    '<button type="button" data-copy="'+esc(h)+'" aria-label="Copy link to '+esc(name)+'">Copy link</button></div>';
}
var FAILED={}; // round scripts whose preload failed: no button can get them until Reload
/** say(t): tells screen readers a button result through the hidden live region #say. */
function say(t){var e=document.getElementById('say');if(e)e.textContent=t}
/** loadFailed(b): the script never loaded, so neither button can work; Reload is the only way on. */
function loadFailed(b){b.textContent='Could not load the script: press Reload';b.disabled=true;say(b.textContent)}
/** blocked(b): the script loaded but the browser blocked the clipboard; the .txt file still has it. */
function blocked(b){b.textContent='Copy blocked: use Open as .txt, then Ctrl+A, Ctrl+C in Notepad';b.disabled=true;say(b.textContent)}
/**
 * copyScript(b): copies the preloaded round script of button b, or says why it cannot.
 * @param {Element} b the Copy script button.
 */
function copyScript(b){
  var h=b.getAttribute('data-script'),t=SCRIPTS[h];
  if(typeof t!=='string'){
    if(b.getAttribute('data-state')==='loading'){b.textContent='Still loading; press again in a moment'}else{loadFailed(b)}
    return}
  // ok: show the line count and the next step, then the label again
  var ok=function(){b.textContent='Copied ('+t.split('\n').length.toLocaleString()+' lines). Now paste in ISE.';say(b.textContent);later(b,'Copy script',4000)};
  // viaArea: the hidden text area copy; returns true when the browser copied
  var viaArea=function(){return fallback(t)};
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(ok,function(){viaArea()?ok():blocked(b)})}else{viaArea()?ok():blocked(b)}
}
/** txtName(h): the .txt file name for script link h (name.ps1 -> name.txt). */
function txtName(h){return h.split('/').pop().replace(/\.ps1$/i,'')+'.txt'}
/**
 * openTxt(b): saves the loaded script as a plain .txt file, so the user can read it in Notepad before pasting (PFM 20 Nov 26).
 * The label comes back from data-label, so a second click cannot keep the "Saved" text.
 * @param {Element} b the Open as .txt button.
 */
function openTxt(b){
  var h=b.getAttribute('data-txt'),t=SCRIPTS[h],lbl=b.getAttribute('data-label');
  if(typeof t!=='string'){
    b.textContent=FAILED[h]?'Could not load the script: press Reload':'Still loading; press again in a moment';say(b.textContent);
    later(b,lbl,4000);return}
  var u=URL.createObjectURL(new Blob([t],{type:'text/plain;charset=utf-8'})),a=document.createElement('a');
  a.href=u;a.download=txtName(h);a.style.display='none';document.body.appendChild(a);a.click();document.body.removeChild(a);
  // free the file link after the download started
  setTimeout(function(){URL.revokeObjectURL(u)},10000);
  b.textContent='Saved '+a.download+'. Open it from Downloads.';say(b.textContent);
  later(b,lbl,4000);
}
/**
 * preload(m): starts the download of each round script on the page, so one click copies it.
 * @param {Element} m the page main element.
 */
function preload(m){
  Array.prototype.forEach.call(m.querySelectorAll('button[data-script]'),function(b){
    var h=b.getAttribute('data-script');b.textContent='Copy script (loading)';b.setAttribute('data-state','loading');
    fetch(h,{cache:'no-store'}).then(function(r){if(!r.ok)throw new Error('HTTP '+r.status);return r.text()})
      .then(function(t){SCRIPTS[h]=t;b.removeAttribute('data-state');b.disabled=false;b.textContent='Copy script'})
      .catch(function(){FAILED[h]=true;b.removeAttribute('data-state');loadFailed(b)});
  });
}
/* Safe DOM (fleet v2): the renderer escapes every go.md text (esc) before it builds HTML text. put() adds a second
   guard: it parses that text in an inert document (DOMParser runs no script and loads nothing) and copies only the tags
   and attributes the renderer makes; a link keeps its href only for http(s) or #, a script button only for https. */
var TAGS={A:1,B:1,BUTTON:1,CODE:1,DETAILS:1,DIV:1,H2:1,H3:1,LI:1,NAV:1,OL:1,P:1,SECTION:1,SPAN:1,STRONG:1,SUMMARY:1,UL:1};
var ATTRS={'class':1,id:1,href:1,rel:1,type:1,value:1,open:1,'aria-label':1,'data-name':1,'data-script':1,'data-txt':1,'data-label':1,'data-copy':1};
/** keepAttr(name, value): true when attribute name=value may be copied to the page. */
function keepAttr(n,v){
  if(!ATTRS[n])return false;
  if(n==='href')return /^(https?:\/\/|#)/i.test(v);
  if(n==='data-script'||n==='data-txt')return /^https:\/\//i.test(v);
  return true;
}
/** copyClean(src, dst): copies the allowed elements, their allowed attributes and all text of src into dst. */
function copyClean(src,dst){
  Array.prototype.forEach.call(src.childNodes,function(n){
    if(n.nodeType===3){dst.appendChild(document.createTextNode(n.nodeValue));return}
    if(n.nodeType!==1||!TAGS[n.tagName])return; // a comment, script, style, img or any other element is dropped with its content
    var e=document.createElement(n.tagName.toLowerCase());
    Array.prototype.forEach.call(n.attributes,function(a){if(keepAttr(a.name,a.value))e.setAttribute(a.name,a.value)});
    copyClean(n,e);dst.appendChild(e);
  });
}
/** put(el, html): replaces the content of el with the allowed part of the HTML text html (see copyClean). */
function put(el,html){
  var d=new DOMParser().parseFromString('<!DOCTYPE html><body>'+html,'text/html');
  while(el.firstChild)el.removeChild(el.firstChild);
  copyClean(d.body,el);
}
/** text(tag, t): a new element with plain text content. */
function text(tag,t){var e=document.createElement(tag);e.textContent=t;return e}
/**
 * folderBox(lbl, path): the HTML of a folder line with a Copy button.
 * @param {string} lbl the label.
 * @param {string} path the folder path.
 * @returns {string} the HTML.
 */
function folderBox(lbl,path){
  return '<div class="folder"><span class="lbl">'+esc(lbl)+'</span><code>'+esc(path)+'</code>'+
    '<button type="button" data-copy="'+esc(path)+'" aria-label="Copy folder path">Copy</button></div>';
}
/**
 * renderBody(lines): the HTML of a card body: lists, file cards, folder lines, notes, sub-headings, paragraphs.
 * @param {string[]} lines the go.md lines of the card.
 * @returns {string} the HTML.
 */
function renderBody(lines){
  var o='',list=null,item=false;
  // closeItem: end the open list item
  function closeItem(){if(item){o+='</li>';item=false}}
  // closeList: end the open list
  function closeList(){closeItem();if(list){o+='</'+list+'>';list=null}}
  lines.forEach(function(l){
    var t=l.trim(),m;
    if(!t){return}
    if(/^(https?:\/\/|raw\.githubusercontent\.com\/)\S+$/.test(t)){ // bare URL line: file card, kept inside the open step
      o+=fileCard(t);return;
    }
    if((m=t.match(/^(\d+)\.\s+(.*)$/))){
      if(list!=='ol'){closeList();o+='<ol>';list='ol'}
      closeItem();o+='<li value="'+m[1]+'">'+inl(m[2]);item=true;return;
    }
    if((m=t.match(/^[-*]\s+(.*)$/))){
      if(list!=='ul'){closeList();o+='<ul class="done-list">';list='ul'}
      closeItem();o+='<li>'+inl(m[1]);item=true;return;
    }
    closeList();
    if((m=t.match(/^(Folder|Bookmark[^:]*|Fallback[^:]*):\s*(.*)$/))&&/[\\\/]/.test(m[2])){
      var path=m[2].replace(/\.\s.*$/,''),rest=m[2].slice(path.length).replace(/^\.\s*/,'');
      o+=folderBox(m[1]+':',path)+(rest?'<p>'+inl(rest)+'</p>':'');return;
    }
    if((m=t.match(/^(Report|Status[^:]*|Decided|FAIL|WARN):\s*(.*)$/))){o+='<p class="note"><span class="lbl">'+esc(m[1])+':</span> '+inl(m[2])+'</p>';return}
    if(/^[A-Z][^.]{2,80}:$/.test(t)||/^Part [A-Z]\b.*:$/.test(t)){o+='<h3>'+inl(t.slice(0,-1))+'</h3>';return}
    o+='<p>'+inl(t)+'</p>';
  });
  closeList();
  return o;
}
/* go.md layout the page reads (PFM 1B, 18 Nov 26: one renderer for many apps and layouts later):
   "# Title", intro lines, then "## " sections. A section with "### " sub-headings is a GROUP: its
   lines before the first "###" are the group's intro, and each "###" is one card. A section with no
   "###" is one card, as before. A card's state comes from "(open, <when>)" or "(done, <when>)" at the
   end of its heading, else from its group ("Open tasks" = open, "Done" = done). */

/**
 * parse(md): splits go.md text into {title, intro[], secs[{h, lines[], items[{h, lines[]}]}]}.
 * @param {string} md the go.md text.
 * @returns {object} the parsed document.
 */
function parse(md){
  var lines=md.replace(/\r/g,'').split('\n'),doc={title:'',intro:[],secs:[]},sec=null,item=null;
  lines.forEach(function(l){
    if(/^# /.test(l)&&!doc.title){doc.title=l.slice(2);return}
    if(/^## /.test(l)){sec={h:l.slice(3),lines:[],items:[]};item=null;doc.secs.push(sec);return}
    if(/^### /.test(l)&&sec){item={h:l.slice(4),lines:[]};sec.items.push(item);return}
    (item?item.lines:sec?sec.lines:doc.intro).push(l);
  });
  return doc;
}
/** stateOf(h, fallback): reads "(open|done, when)" from a heading; returns {name, state, when}. */
function stateOf(h,fallback){
  var m=h.match(/^(.*?)\s*\((open|done)[,\s]*([^)]*)\)\s*$/i);
  if(m)return {name:m[1],state:m[2].toLowerCase(),when:m[3]};
  return {name:h,state:fallback||'',when:''};
}
/** groupState(h): the state a group gives its "###" cards: "Open tasks" = open, "Done" = done, else none. */
function groupState(h){return /^open tasks$/i.test(h)?'open':/^done$/i.test(h)?'done':''}
/** card(info, lines, id, st, extra): one collapsible card; open by default when its state is open,
    unless this browser remembered another choice for the same name (st). */
function card(info,lines,id,st,extra){
  var isOpen=Object.prototype.hasOwnProperty.call(st,info.name)?st[info.name]:(info.state==='open');
  var cls='sec'+(info.state==='open'?' open-task':info.state==='done'?' done-task':'');
  var chip=info.state?'<span class="chip '+info.state+'">'+(info.state==='open'?'Open':'Done')+'</span>':'';
  return '<details class="'+cls+'" id="'+id+'" data-name="'+esc(info.name)+'"'+(isOpen?' open':'')+
    '><summary><span class="st">'+inl(info.name)+'</span><span class="meta">'+chip+
    (info.when?'<span class="when">'+esc(info.when)+'</span>':'')+(extra||'')+
    '</span></summary><div class="body">'+renderBody(lines)+'</div></details>';
}
/** doneCount(lines): the "N items" label of a Done list (one item per "- " line). */
function doneCount(lines){return '<span class="when">'+lines.filter(function(x){return /^\s*-\s/.test(x)}).length+' items</span>'}
/**
 * renderSecs(secs, st): builds the section links, the cards and the open count for all sections.
 * @param {object[]} secs the sections from parse.
 * @param {object} st the remembered open state.
 * @returns {object} {nav, body, open}.
 */
function renderSecs(secs,st){
  var r={nav:'',body:'',open:0},n=0;
  secs.forEach(function(s){
    var gs=groupState(s.h);
    if(!s.items.length){ // a plain section: one card, as before (only "Done" gets a state without "(open|done)")
      var info=stateOf(s.h,gs==='done'?'done':''),id=slug(info.name,n++);
      if(info.state==='open')r.open++;
      r.nav+='<li><a href="#'+id+'"'+(info.state==='open'?' class="is-open"':'')+'>'+inl(info.name)+'</a></li>';
      r.body+=card(info,s.lines,id,st,/^done$/i.test(s.h)?doneCount(s.lines):'');
      return;
    }
    var gid=slug(s.h,n++),cards='',links=''; // a group: a heading, its intro, then one card per "###"
    s.items.forEach(function(it){
      var info=stateOf(it.h,gs),id=slug(info.name,n++);
      if(info.state==='open'){r.open++;links+='<li><a href="#'+id+'" class="is-open">'+inl(info.name)+'</a></li>'}
      cards+=card(info,it.lines,id,st,'');
    });
    r.nav+='<li><a href="#'+gid+'">'+inl(s.h)+' ('+s.items.length+')</a></li>'+links; // each open card keeps its own link
    var intro=s.lines.some(function(x){return x.trim()})?'<div class="gintro">'+renderBody(s.lines)+'</div>':'';
    r.body+='<section class="grp" id="'+gid+'"><h2>'+inl(s.h)+'</h2>'+intro+cards+'</section>';
  });
  return r;
}
/**
 * render(md): draws the whole page from go.md text and wires its buttons.
 * @param {string} md the go.md text.
 */
function render(md){
  var doc=parse(md),st=load(),o='',m=document.getElementById('m');
  var r=renderSecs(doc.secs,st);
  var how=(Object.prototype.hasOwnProperty.call(st,'__how')?st.__how:false);
  var hc=document.getElementById('hc');while(hc.firstChild)hc.removeChild(hc.firstChild);
  hc.appendChild(text('b',String(r.open)));hc.appendChild(document.createTextNode('open task'+(r.open===1?'':'s')));
  o+='<p class="mut">Loaded '+new Date().toLocaleString()+'. GitHub can serve a copy up to 5 minutes old: press Reload for the newest.</p>';
  o+='<div class="bar"><button type="button" id="ex">Expand all</button><button type="button" id="co">Collapse all</button><button type="button" id="rl">Reload</button></div>';
  o+='<nav aria-label="Sections"><ul class="toc">'+r.nav+'</ul></nav>';
  o+='<details class="sec" data-name="__how"'+(how?' open':'')+'><summary><span class="st">How to use this page</span></summary><div class="body">'+renderBody(doc.intro)+'</div></details>';
  var where=CFG?CFG.owner+'/'+CFG.repo:'this repository';
  o+=r.body+'<p class="mut foot">Source: <a href="'+esc(SRC)+'" rel="noopener noreferrer">go.md</a> in '+esc(where)+
    '. Open and closed sections are remembered in this browser.</p>';
  put(m,o);
  wire(m);
}
/**
 * wire(m): copy and .txt buttons, script preload, remembered open state, Expand/Collapse/Reload, links, print.
 * @param {Element} m the page main element.
 */
function wire(m){
  m.addEventListener('click',function(e){
    // f: the clicked element or its nearest parent that matches sel
    var f=function(sel){return e.target.closest&&e.target.closest(sel)};
    var s=f('button[data-script]');if(s){e.preventDefault();copyScript(s);return}
    var v=f('button[data-txt]');if(v){e.preventDefault();openTxt(v);return}
    var b=f('button[data-copy]');if(b){e.preventDefault();copy(b.getAttribute('data-copy'),b)}});
  preload(m);
  // all: every card on the page
  var all=function(){return Array.prototype.slice.call(m.querySelectorAll('details.sec'))};
  all().forEach(function(d){d.addEventListener('toggle',function(){var s=load();s[d.getAttribute('data-name')]=d.open;save(s)})});
  document.getElementById('ex').onclick=function(){all().forEach(function(d){d.open=true})};
  document.getElementById('co').onclick=function(){all().forEach(function(d){d.open=false})};
  document.getElementById('rl').onclick=function(){location.reload()};
  m.querySelectorAll('.toc a').forEach(function(a){a.addEventListener('click',function(){var d=document.getElementById(a.getAttribute('href').slice(1));if(d&&d.tagName==='DETAILS')d.open=true})});
  if(location.hash){var d=document.getElementById(location.hash.slice(1));if(d){if(d.tagName==='DETAILS')d.open=true;d.scrollIntoView()}}
  window.addEventListener('beforeprint',function(){all().forEach(function(d){d.open=true})});
}
/**
 * failed(e): shows why go.md did not load, with a link to it (or to TASKS.md, the copy on github.com) as text and href.
 * @param {Error} e the error.
 */
function failed(e){
  var m=document.getElementById('m'),p=text('p','Could not load go.md ('+e.message+'). Fallback: '),a=text('a',SRC||'TASKS.md');
  a.href=SRC||'TASKS.md';a.rel='noopener noreferrer';p.appendChild(a);
  while(m.firstChild)m.removeChild(m.firstChild);m.appendChild(p);
}
/**
 * tagCfg(e): the owner, repo and branch from the data-owner, data-repo and data-branch attributes of the go.js tag.
 * @param {Element} e the script element (or null).
 * @returns {object|null} the config, or null when there is no tag.
 */
function tagCfg(e){return e?{owner:e.getAttribute('data-owner'),repo:e.getAttribute('data-repo'),branch:e.getAttribute('data-branch')}:null}
/**
 * start(): exposes the functions to tests/check_go_page.js, or draws a given go.md text, or reads the config from the
 * go.js script tag, then loads go.md, and draws the page.
 */
function start(){
  if(window.GO_TEST&&typeof window.GO_TEST==='object'){
    var T=window.GO_TEST;T.parse=parse;T.renderSecs=renderSecs;T.txtName=txtName;T.validState=validState;
    T.validCfg=validCfg;T.keepAttr=keepAttr;T.rawBase=rawBase;T.tagCfg=tagCfg;return}
  if(typeof window.GO_MD==='string'){render(window.GO_MD);return}
  var c=tagCfg(ME);
  if(!validCfg(c)){failed(new Error('the go.js tag has no valid data-owner, data-repo and data-branch'));return}
  CFG=c;SRC=rawBase(c)+'go.md';
  fetch(SRC,{cache:'no-store'})
    .then(function(r){if(!r.ok)throw new Error('HTTP '+r.status);return r.text()}).then(render).catch(failed);
}
start();
