import Foundation

enum Scripts {
    /// Catches in-page (pushState / click) navigation that WKNavigationDelegate never sees.
    static func guardScript(for site: Site) -> String {
        let blocked = (try? String(data: JSONEncoder().encode(site.blockedPrefixes), encoding: .utf8)) ?? "[]"
        let start = (try? String(data: JSONEncoder().encode(site.start.absoluteString), encoding: .utf8)) ?? "\"/\""
        let force = site.forceQuery.map { "\"\($0)\"" } ?? "null"
        let embed = site.embedReels ? "true" : "false"
        return """
        (function(){
          var blocked=\(blocked), start=\(start), force=\(force), embed=\(embed);
        var reelRe=/^\\/(?:[^\\/]+\\/)?reel\\/([^\\/]+)\\/?$/;
          function isBlocked(p){ for(var i=0;i<blocked.length;i++) if(p.indexOf(blocked[i])===0) return true; return false; }
          function check(){
            var p=location.pathname, m=embed&&reelRe.exec(p);
            if(m){ location.replace('/reel/'+m[1]+'/embed/'); return; }
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

    /// YouTube: hides anything that links to /shorts, the "Shorts" tab (a button without a link),
    /// and every video card whose duration badge is <= 1:00 (Shorts are often served as /watch
    /// links, so the URL alone cannot tell them apart).
    static let youtube = """
    (function(){
      var MAX=60;
      var CARD='ytm-rich-item-renderer,ytm-video-with-context-renderer,ytm-compact-video-renderer,'
        +'ytm-compact-autoplay-renderer,ytm-media-item,yt-lockup-view-model,'
        +'ytm-reel-shelf-renderer,ytm-shelf-renderer,ytm-pivot-bar-item-renderer,ytm-rich-section-renderer';
      var VIDEO='ytm-rich-item-renderer,ytm-video-with-context-renderer,ytm-compact-video-renderer,'
        +'ytm-compact-autoplay-renderer,ytm-media-item,yt-lockup-view-model';
      var TIME=/^(?:(\\d+):)?(\\d{1,2}):(\\d{2})$/;
      var st=document.createElement('style');
      st.textContent='ytm-rich-section-renderer:has(ytm-reel-shelf-renderer),ytm-reel-shelf-renderer,'
        +'ytm-shorts-lockup-view-model,ytm-shorts-lockup-view-model-v2{display:none!important}';
      function seconds(t){
        var m=TIME.exec(t.trim()); if(!m) return -1;
        return (+m[1]||0)*3600+(+m[2])*60+(+m[3]);
      }
      function sweep(){
        if(!st.isConnected) (document.head||document.documentElement).appendChild(st);
        document.querySelectorAll('a[href*="/shorts"]').forEach(function(a){
          (a.closest(CARD)||a).style.display='none';
        });
        document.querySelectorAll('ytm-pivot-bar-item-renderer').forEach(function(i){
          if(/^\\s*shorts\\s*$/i.test(i.textContent)) i.style.display='none';
        });
        document.querySelectorAll(VIDEO).forEach(function(c){
          if(c.style.display==='none') return;
          var all=c.querySelectorAll('*');
          for(var k=0;k<all.length;k++){
            var l=all[k];
            if(l.childElementCount) continue;
            var s=seconds(l.textContent);
            if(s>=0){ if(s<=MAX) c.style.display='none'; return; }
          }
        });
      }
      var t; new MutationObserver(function(){ clearTimeout(t); t=setTimeout(sweep,50); })
        .observe(document,{childList:true,subtree:true});
      document.addEventListener('DOMContentLoaded',sweep);
    })();
    """

    /// Instagram: hides Reels links, the Explore grid and suggested posts, kills scroll-snap
    /// (feed videos snapping to full screen) and locks scrolling only while a single reel is open.
    static let instagram = """
    (function(){
      var SUGGESTED=/suggested for you|suggested posts|vorgeschlagen für dich|vorgeschlagene beiträge/i;
      var REEL=/(^|\\/)reel\\/[^\\/]+/;
      function hide(el){ el.style.display='none'; }
      function onReel(){ return REEL.test(location.pathname); }
      var snap=document.createElement('style');
      snap.textContent='*{scroll-snap-type:none!important}';
      var lock=document.createElement('style');
      lock.id='ff-lock';
      lock.textContent='html,body{overflow:hidden!important;overscroll-behavior:none!important}';
      document.addEventListener('touchmove',function(e){ if(onReel()) e.preventDefault(); },{passive:false});
      function sweep(){
        var root=document.documentElement, p=location.pathname;
        if(!snap.isConnected) root.appendChild(snap);
        document.querySelectorAll('a[href^="/reels"]').forEach(hide);
        if(p==='/explore'||p==='/explore/')
          document.querySelectorAll('a[href*="/p/"],a[href*="/reel/"]').forEach(hide);
        document.querySelectorAll('article').forEach(function(a){
          if(SUGGESTED.test((a.innerText||a.textContent||'').slice(0,300))) hide(a);
        });
        if(onReel()){
          document.querySelectorAll('a[href*="/reel/"]').forEach(function(a){
            if(new URL(a.href,location.href).pathname!==p) hide(a);
          });
          if(!lock.isConnected) root.appendChild(lock);
        } else if(lock.isConnected){
          lock.remove();
        }
      }
      var t; new MutationObserver(function(){ clearTimeout(t); t=setTimeout(sweep,50); })
        .observe(document,{childList:true,subtree:true});
      document.addEventListener('DOMContentLoaded',sweep);
    })();
    """
}
