import Foundation

enum Scripts {
    /// Catches in-page (pushState / click) navigation that WKNavigationDelegate never sees.
    static func guardScript(for site: Site) -> String {
        let blocked = (try? String(data: JSONEncoder().encode(site.blockedPrefixes), encoding: .utf8)) ?? "[]"
        let start = (try? String(data: JSONEncoder().encode(site.start.absoluteString), encoding: .utf8)) ?? "\"/\""
        let force = site.forceQuery.map { "\"\($0)\"" } ?? "null"
        return """
        (function(){
          var blocked=\(blocked), start=\(start), force=\(force);
          function isBlocked(p){ for(var i=0;i<blocked.length;i++) if(p.indexOf(blocked[i])===0) return true; return false; }
          function check(){
            var p=location.pathname;
            if(isBlocked(p) || (force && p==='/' && location.search.indexOf(force)<0)) location.replace(start);
          }
          ['pushState','replaceState'].forEach(function(k){
            var o=history[k];
            history[k]=function(){ var r=o.apply(this,arguments); check(); return r; };
          });
          addEventListener('popstate',check);
          document.addEventListener('click',function(e){
            var a=e.target.closest&&e.target.closest('a[href]'); if(!a) return;
            var u=new URL(a.href,location.href);
            if(u.host===location.host && isBlocked(u.pathname)){ e.preventDefault(); e.stopPropagation(); }
          },true);
          check();
        })();
        """
    }

    /// Anchor-based: any link to /shorts gets its nearest card/shelf hidden.
    static let youtube = """
    (function(){
      var CARD='ytm-rich-item-renderer,ytm-video-with-context-renderer,ytm-compact-video-renderer,'
        +'ytm-reel-shelf-renderer,ytm-shelf-renderer,ytm-pivot-bar-item-renderer,ytm-rich-section-renderer';
      var st=document.createElement('style');
      st.textContent='ytm-rich-section-renderer:has(ytm-reel-shelf-renderer),ytm-reel-shelf-renderer,'
        +'ytm-shorts-lockup-view-model,ytm-shorts-lockup-view-model-v2{display:none!important}';
      function sweep(){
        if(!st.isConnected) (document.head||document.documentElement).appendChild(st);
        document.querySelectorAll('a[href*="/shorts"]').forEach(function(a){
          (a.closest(CARD)||a).style.display='none';
        });
      }
      var t; new MutationObserver(function(){ clearTimeout(t); t=setTimeout(sweep,50); })
        .observe(document,{childList:true,subtree:true});
      document.addEventListener('DOMContentLoaded',sweep);
    })();
    """

    static let instagram = """
    (function(){
      var SUGGESTED=/suggested for you|suggested posts|vorgeschlagen für dich|vorgeschlagene beiträge/i;
      var locked=false;
      function hide(el){ el.style.display='none'; }
      function sweep(){
        var p=location.pathname;
        document.querySelectorAll('a[href^="/reels"]').forEach(hide);
        if(p==='/explore'||p==='/explore/')
          document.querySelectorAll('a[href*="/p/"],a[href*="/reel/"]').forEach(hide);
        document.querySelectorAll('article').forEach(function(a){
          if(SUGGESTED.test((a.innerText||'').slice(0,300))) hide(a);
        });
        if(p.indexOf('/reel/')===0){
          document.querySelectorAll('a[href*="/reel/"]').forEach(function(a){
            if(new URL(a.href,location.href).pathname!==p) hide(a);
          });
          if(!locked){
            locked=true;
            var st=document.createElement('style');
            st.textContent='html,body{overflow:hidden!important;overscroll-behavior:none!important}';
            document.documentElement.appendChild(st);
            document.addEventListener('touchmove',function(e){ e.preventDefault(); },{passive:false});
          }
        }
      }
      var t; new MutationObserver(function(){ clearTimeout(t); t=setTimeout(sweep,50); })
        .observe(document,{childList:true,subtree:true});
      document.addEventListener('DOMContentLoaded',sweep);
    })();
    """
}
