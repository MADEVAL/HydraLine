/// Virtual views JS (≤2 KB).
///
/// Manages `hydraline-island-segment` elements for tall islands that exceed
/// the canvas size limit. Uses a shared `IntersectionObserver` to
/// mount/unmount segments as they enter/leave the viewport.
library;

const jsVirtualViews = r'''
(function(){var io=null;function init(){var segs=document.querySelectorAll(
'hydraline-island-segment');if(!segs.length)return;io=new IntersectionObserver(
function(entries){entries.forEach(function(e){e.target.dispatchEvent(
new CustomEvent(e.isIntersecting?'hydraline:segment-enter':'hydraline:segment-leave',
{bubbles:!0}))})},{rootMargin:'400px'});
segs.forEach(function(s){io.observe(s)})}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);
else init()})();
''';
