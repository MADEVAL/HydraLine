(function(){'use strict';
var doc=document;
function init(){
  if(doc.querySelector('[data-island="htmx"], [data-island-level="htmx"]')){
    var s=doc.createElement('script');
    s.src='/assets/hydraline/htmx.min.js';
    s.async=true;
    var loading=doc.createElement('div');
    loading.id='hydraline-htmx-status';
    loading.style.cssText='position:fixed;top:4px;right:4px;z-index:9999;'+
      'background:#eee;color:#333;padding:2px 8px;border-radius:4px;font-size:11px;display:none';
    doc.body.appendChild(loading);
    doc.addEventListener('htmx:beforeRequest',function(){
      loading.style.display='';loading.textContent='loading\u2026'});
    doc.addEventListener('htmx:afterRequest',function(){
      loading.textContent='\u2713';setTimeout(function(){loading.style.display='none'},800)});
    doc.head.appendChild(s);
  }
}
if(doc.readyState==='loading'){doc.addEventListener('DOMContentLoaded',init)}
else{init()}
})();
