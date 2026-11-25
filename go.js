// go.js: wires the bookmark page (index.html). The task cards are in the page already: scripts/build_go_page.py builds
// them from go.md at build time (master plan P4b, 2026-11-24), so this script turns no text into HTML. It adds the
// buttons (Copy, Copy script, Open as .txt), the remembered open state, Expand/Collapse/Reload, and the print view.
// Runs in the browser; tests/check_go_page.js loads it in node with window.GO_TEST set.
// Network: the round scripts for the Copy script button, from the data-script address the build wrote (the page CSP
// connect-src allows only this repository's branch folder on raw.githubusercontent.com).
// Writes: this browser's localStorage key go-open-v1 (which cards are open).
// Credentials: none.
'use strict';
var KEY='go-open-v1';
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
 * applyState(m, st): opens or closes each card as this browser remembered it; a card with no remembered choice keeps
 * the state the build gave it (open tasks open).
 * @param {Element} m the page main element.
 * @param {object} st the remembered open state (validState).
 */
function applyState(m,st){
  Array.prototype.forEach.call(m.querySelectorAll('details.sec'),function(d){
    var n=d.getAttribute('data-name');
    if(n!==null&&Object.prototype.hasOwnProperty.call(st,n))d.open=st[n];
  });
}
/**
 * start(): exposes the functions to tests/check_go_page.js, or wires the page.
 */
function start(){
  if(window.GO_TEST&&typeof window.GO_TEST==='object'){
    var T=window.GO_TEST;T.validState=validState;T.txtName=txtName;T.applyState=applyState;return}
  var m=document.getElementById('m');
  applyState(m,load());
  wire(m);
}
start();
