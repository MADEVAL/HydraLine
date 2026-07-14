/// Standalone vanilla-islands JavaScript bundle for level-1 interactivity
/// (ARCHITECTURE.md §13; C-12).
///
/// Enhances static HTML elements tagged with `data-island` attributes. Runs on
/// `DOMContentLoaded` and does not depend on Flutter or any other runtime.
/// Budget: ≤ 8 KB uncompressed.
///
/// Self-hosted, first-party, compatible with CSP `script-src 'self'`.
library;

const vanillaIslandsJs = r'''
(function(){'use strict';
var h={};function g(n,c){h[n]||(h[n]=[]);h[n].push(c)}function e(n,d){if(h[n]){for(var i=0;i<h[n].length;i++)h[n][i](d);h[n]=[]}}

function $(s,p){return(p||document).querySelector(s)}
function $$(s,p){return(p||document).querySelectorAll(s)}

function each(sel,fn){var els=$$(sel);for(var i=0;i<els.length;i++)fn(els[i],i)}
function attr(el,name,val){return val===undefined?el.getAttribute(name):el.setAttribute(name,val)}

/* Accordion -- animates <details> inside [data-island="accordion"] */
function Accordion(root){var d=root.querySelector('details'),s=d?d.querySelector('summary'):null;
if(d){s.addEventListener('click',function(ev){ev.preventDefault();d.open=!d.open;
attr(d,'aria-expanded',String(d.open))})}}g('accordion',Accordion);

/* Tabs -- [data-island="tabs"] with [data-tab] buttons and [data-panel] panels */
function Tabs(root){var btns=$$('[data-tab]',root),pnls=$$('[data-panel]',root);
function show(id){for(var i=0;i<pnls.length;i++)pnls[i].hidden=pnls[i].getAttribute('data-panel')!==id;
for(var j=0;j<btns.length;j++){var b=btns[j];var act=b.getAttribute('data-tab')===id;
b.setAttribute('aria-selected',String(act));b.classList.toggle('active',act)}}for(var k=0;k<btns.length;k++)
btns[k].addEventListener('click',function(){show(this.getAttribute('data-tab'))})}g('tabs',Tabs);

/* Carousel -- [data-island="carousel"] slides */
function Carousel(root){var slides=$$('[data-slide]',root),idx=0;function go(i){
idx=((i%slides.length)+slides.length)%slides.length;for(var s=0;s<slides.length;s++)
slides[s].hidden=s!==idx;attr(root,'data-slide-index',String(idx))}
root.querySelector('[data-carousel-prev]').addEventListener('click',function(){go(idx-1)});
root.querySelector('[data-carousel-next]').addEventListener('click',function(){go(idx+1)});go(0)}g('carousel',Carousel);

/* Copy-button -- [data-island="copy-button"] */
function CopyButton(root){var btn=$('[data-copy-target]',root)||root.querySelector('button');
var targetId=attr(btn,'data-copy-target');if(!targetId)return;btn.addEventListener('click',function(){
var src=$(targetId);if(!src)return;navigator.clipboard.writeText(src.textContent||'').then(function(){
attr(root,'data-copied','1');setTimeout(function(){root.removeAttribute('data-copied')},2000)})})}
g('copy-button',CopyButton);

/* Lazy-image -- [data-island="lazy-image"] via IntersectionObserver */
function LazyImage(root){var img=root.querySelector('img');if(!img)return;
if(!('IntersectionObserver' in window)){img.src=attr(img,'data-src')||'';return}
var io=new IntersectionObserver(function(entries,obs){entries.forEach(function(e){if(e.isIntersecting){
img.src=attr(img,'data-src')||'';obs.unobserve(img)}})},{rootMargin:'200px'});io.observe(img)}g('lazy-image',LazyImage);

/* Theme -- [data-island="theme"] toggles color-scheme via data-theme */
function Theme(root){var btn=root.querySelector('button');if(!btn)return;
var key='hydraline-theme';function apply(t){document.documentElement.setAttribute('data-theme',t);
localStorage.setItem(key,t)}var current=localStorage.getItem(key)||
(window.matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light');apply(current);
btn.addEventListener('click',function(){apply(current==='dark'?'light':'dark');current=current==='dark'?'light':'dark'})}
g('theme',Theme);

/* Bootstrap -- called on DOMContentLoaded */
document.addEventListener('DOMContentLoaded',function(){
each('[data-island]',function(el){var kind=attr(el,'data-island');if(h[kind])
for(var i=0;i<h[kind].length;i++)h[kind][i](el)});
each('[data-island-level="vanilla"]',function(el){var kind=attr(el,'data-island');
if(h[kind])for(var i=0;i<h[kind].length;i++)h[kind][i](el)})});
})();
''';
