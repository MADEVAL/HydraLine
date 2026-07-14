/// Dispatcher JS (W-9, Qwikloader-style, ≤2 KB).
///
/// Global `window.hydraline` API, all hydration directives
/// (onLoad/onIdle/onVisible/onInteraction/onMedia/manual), `data-hydration`
/// lifecycle, timeout and retry.
library;

const jsDispatcher = r'''
(function(){var A=document,B=window,io=null,idle=null,listening=!1,
engineLoading=!1,engineLoaded=!1,loadEngine=null;
function E(id){return A.querySelector('hydraline-island[id="'+id+'"]')||
A.querySelector('[data-island="htmx"][id="'+id+'"]')}
function S(el,state){el.setAttribute('data-hydration',state)}
function F(el,reason){S(el,'failed');el.dispatchEvent(new CustomEvent(
'hydraline:island-error',{bubbles:!0,detail:{id:el.id,reason:reason}}))}
function L(id,factory){var el=E(id);if(!el)return;S(el,'hydrating');
var t=setTimeout(function(){F(el,'timeout')},15000);
factory().then(function(){clearTimeout(t);S(el,'hydrated')},
function(r){clearTimeout(t);F(el,r+'')})}
function startEngine(id,factory){
if(engineLoaded){L(id,factory);return}
if(engineLoading){(loadEngine=loadEngine||[]).push([id,factory]);return}
engineLoading=!0;var s=A.createElement('script');s.src='/main.dart.js';
s.onload=function(){engineLoaded=!0;L(id,factory);
(loadEngine||[]).forEach(function(p){L(p[0],p[1])});loadEngine=null};
A.head.appendChild(s)}
B.hydraline={hydrate:function(id){
var el=E(id);if(!el||el.getAttribute('data-hydration')==='hydrated')return;
var d=el.getAttribute('data-island-level')==='htmx'?null:startEngine;if(d)d(id,function(){return Promise.resolve()})},
hydrateAll:function(){var els=A.querySelectorAll('hydraline-island[data-directive="hydrateManual"],[data-island="htmx"][data-directive="hydrateManual"]');
for(var i=0;i<els.length;i++)B.hydraline.hydrate(els[i].id)},
version:'0.1.0'};
A.addEventListener('DOMContentLoaded',function(){
var els=A.querySelectorAll('hydraline-island');
for(var i=0;i<els.length;i++){(function(el){
var d=el.getAttribute('data-directive');
if(d==='hydrateOnLoad'){B.hydraline.hydrate(el.id)}}
)(els[i])}
var onVisible=A.querySelectorAll('hydraline-island[data-directive="hydrateOnVisible"]');
if(onVisible.length&&!io){io=new IntersectionObserver(function(entries,obs){
entries.forEach(function(e){if(e.isIntersecting){B.hydraline.hydrate(e.target.id);
obs.unobserve(e.target)}})},{rootMargin:'200px'});
for(var i=0;i<onVisible.length;i++)io.observe(onVisible[i])}
var onIdle=A.querySelectorAll('hydraline-island[data-directive="hydrateOnIdle"]');
if(onIdle.length&&!idle){idle=function(){for(var i=0;i<onIdle.length;i++)
B.hydraline.hydrate(onIdle[i].id)};(B.requestIdleCallback||setTimeout)(idle)}
if(!listening){listening=!0;
A.addEventListener('click',function(ev){var el=ev.target;
while(el&&el!==A){if(el.matches&&el.matches('hydraline-island[data-directive="hydrateOnInteraction"]')){
B.hydraline.hydrate(el.id);return}el=el.parentNode}},!0)}var onMedia=A.querySelectorAll(
'hydraline-island[data-directive="hydrateOnMedia"]');for(var i=0;i<onMedia.length;i++){
(function(el){var m=el.getAttribute('data-media');
if(m&&B.matchMedia(m).matches)B.hydraline.hydrate(el.id)})(onMedia[i])}});
})();
''';
