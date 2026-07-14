/// Custom Element `<hydraline-island>` (W-8/CE1-CE5).
///
/// Uses Declarative Shadow DOM — the existing Shadow Root from server-rendered
/// `<template shadowrootmode="open">` is reused, so there is no FOUC (CE1).
/// Budget: ≤ 2 KB.
library;

const jsCustomElement = r'''
customElements.define('hydraline-island',class extends HTMLElement{
constructor(){super();this._obs=null}
connectedCallback(){
var t=this;
if(t.getAttribute('data-hydration')==='hydrated')return;
var sr=t.shadowRoot;
if(!sr){sr=t.attachShadow({mode:'open'});t.innerHTML='';t.appendChild(
document.createElement('template').content)}var style=sr.querySelector('style');
if(!style){style=document.createElement('style');sr.insertBefore(style,sr.firstChild)}
style.textContent+=':host{display:block;contain:layout style paint}';
var size=t.getAttribute('data-size');
if(size){var wh=size.split(',');style.textContent+='.host{width:'+wh[0]+'px;height:'+wh[1]+'px}'}
var raf=null,views=[];
if(!t._obs&&window.ResizeObserver)try{t._obs=new ResizeObserver(function(es){
if(raf){cancelAnimationFrame(raf)}raf=requestAnimationFrame(function(){
var ua=navigator.userAgent||'';
if(ua.indexOf('Flutter/3.41')>-1)return;
for(var i=0;i<es.length;i++){
var e=es[i].target,w=e.offsetWidth,h=e.offsetHeight;
try{e.style.setProperty('width',w+'px','important');
e.style.setProperty('height',h+'px','important')}catch(_){}}}});
t._obs.observe(t)}catch(_){}}
disconnectedCallback(){if(this._obs){this._obs.disconnect();this._obs=null}}
});
''';
