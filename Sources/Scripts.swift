import Foundation

enum Scripts {
    /// Catches in-page (pushState / click) navigation that WKNavigationDelegate never sees.
    static func guardScript(for site: Site) -> String {
        let blocked = (try? String(data: JSONEncoder().encode(site.blockedPrefixes), encoding: .utf8)) ?? "[]"
        let start = (try? String(data: JSONEncoder().encode(site.start.absoluteString), encoding: .utf8)) ?? "\"/\""
        let force = site.forceQuery.map { "\"\($0)\"" } ?? "null"
        let terms = site.allowedSearches.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) } ?? "null"
        return """
        (function(){
          var blocked=\(blocked), start=\(start), force=\(force), terms=\(terms);
          function norm(s){ return s.replace(/\\+/g,' ').toLowerCase().trim().split(/\\s+/).join(' '); }
          // Session mode mirrors Site.isAllowed: watch pages, sign-in and results for the session's terms only.
          function allowed(u){
            var p=u.pathname;
            if(p.indexOf('/watch')===0||p.indexOf('/signin')===0) return true;
            var q=u.searchParams.get('search_query');
            return p==='/results' && q!==null && terms.indexOf(norm(q))>=0;
          }
          function isBlocked(p,u){
            if(terms) return !allowed(u);
            for(var i=0;i<blocked.length;i++) if(p.indexOf(blocked[i])===0) return true; return false;
          }
          window.__ffAllowed=function(h){ var u=new URL(h,location.href); return !isBlocked(u.pathname,u); };
          function check(){
            var p=location.pathname;
            if(isBlocked(p,new URL(location.href)) || (force && p==='/' && location.search.indexOf(force)<0)) location.replace(start);
          }
          ['pushState','replaceState'].forEach(function(k){
            var o=history[k];
            history[k]=function(){ var r=o.apply(this,arguments); check(); return r; };
          });
          addEventListener('popstate',check);
          document.addEventListener('click',function(e){
            var a=e.target.closest&&e.target.closest('a[href]'); if(!a) return;
            var u=new URL(a.href,location.href);
            if(u.host===location.host && isBlocked(u.pathname,u)){ e.preventDefault(); e.stopPropagation(); }
          },true);
          check();
        })();
        """
    }

    /// YouTube: hides anything that links to /shorts, the "Shorts" tab (a button without a link),
    /// and every video card whose duration badge is <= 1:00 (Shorts are often served as /watch
    /// links, so the URL alone cannot tell them apart). Hiding is a recomputed C\\s class, not a sticky
    /// inline style: YouTube recycles card elements while scrolling.
    static let youtube = """
    (function(){
      var MAX=60;
      var CARD='ytm-rich-item-renderer,ytm-video-with-context-renderer,ytm-compact-video-renderer,'
        +'ytm-compact-autoplay-renderer,ytm-media-item,yt-lockup-view-model,'
        +'ytm-reel-shelf-renderer,ytm-shelf-renderer,ytm-pivot-bar-item-renderer,ytm-rich-section-renderer';
      var VIDEO='ytm-rich-item-renderer,ytm-video-with-context-renderer,ytm-compact-video-renderer,'
        +'ytm-compact-autoplay-renderer,ytm-media-item,yt-lockup-view-model';
      var TIME=/^(?:(\\d+):)?(\\d{1,2}):(\\d{2})$/;
      // Feed previews autoplay inline (allowsInlineMediaPlayback) and keep cycling through cards.
      // Playback is only allowed on the watch page. Blocking play() alone still flashes YouTube's
      // preview player over the thumbnail, so on all other pages every player is kept invisible.
      window.__ffBlockedPlays=0;
      var lastBlocked='';
      function playAllowed(){ return location.pathname.indexOf('/watch')===0; }
      function syncPlayClass(){
        var r=document.documentElement; if(!r) return;
        r.classList.toggle('ff-noplay',!playAllowed());
        r.classList.toggle('ff-watch',playAllowed());
      }
      ['pushState','replaceState'].forEach(function(k){
        var o=history[k];
        history[k]=function(){ var r=o.apply(this,arguments); syncPlayClass(); return r; };
      });
      addEventListener('popstate',syncPlayClass);
      syncPlayClass();
      function chain(el){
        var out=[];
        for(var n=el,i=0;n&&i<5;n=n.parentElement,i++){
          var q=n.getBoundingClientRect();
          var c=(typeof n.className==='string'&&n.className)?'.'+n.className.split(' ')[0].slice(0,10):'';
          out.push(n.tagName.toLowerCase()+c+'('+Math.round(q.width)+'x'+Math.round(q.height)+')');
        }
        return out.join('<');
      }
      // Mark the blocked video plus wrappers of exactly its size (the preview overlay), never the
      // thumbnail or the card itself. Only applies while html.ff-noplay is set.
      function markOverlay(v){
        try{
          v.classList.add('ff-preview-hidden');
          var r=v.getBoundingClientRect(), n=v.parentElement, k=0;
          while(n&&n!==document.body&&k<6&&!n.matches(VIDEO)){
            var q=n.getBoundingClientRect();
            if(Math.abs(q.width-r.width)>2||Math.abs(q.height-r.height)>2||n.querySelector('img')) break;
            n.classList.add('ff-preview-hidden'); n=n.parentElement; k++;
          }
          lastBlocked=chain(v);
        }catch(e){}
      }
      var origPlay=HTMLMediaElement.prototype.play;
      HTMLMediaElement.prototype.play=function(){
        if(!playAllowed()){
          window.__ffBlockedPlays++;
          markOverlay(this);
          return Promise.reject(new DOMException('FocusFeed: previews are off','NotAllowedError'));
        }
        return origPlay.apply(this,arguments);
      };
      document.addEventListener('play',function(e){
        var v=e.target;
        if(v&&v.tagName==='VIDEO'&&!playAllowed()){ v.pause(); window.__ffBlockedPlays++; markOverlay(v); }
      },true);
      var st=document.createElement('style');
      st.textContent='.ff-hide,ytm-rich-section-renderer:has(ytm-reel-shelf-renderer),ytm-reel-shelf-renderer,'
        +'ytm-shorts-lockup-view-model,ytm-shorts-lockup-view-model-v2{display:none!important}'
        +'html.ff-noplay video,html.ff-noplay .html5-video-player,html.ff-noplay .ff-preview-hidden'
        +'{visibility:hidden!important}'
        // Watch page: every video card is a recommendation; the end screen offers the next one.
        // ponytail: autoplay (autonav) can still advance to the next video; turn it off in the player if it does.
        +VIDEO.split(',').map(function(s){ return 'html.ff-watch '+s; }).join(',')
        +',html.ff-watch [section-identifier="related-items"],html.ff-watch [class*="endscreen"]'
        +'{display:none!important}';
      var sweeps=0, loads=0;
      try{ loads=(+sessionStorage.getItem('ffLoads')||0)+1; sessionStorage.setItem('ffLoads',String(loads)); }catch(e){}
      function seconds(t){
        var m=TIME.exec(t.trim()); if(!m) return -1;
        return (+m[1]||0)*3600+(+m[2])*60+(+m[3]);
      }
      function isShortCard(c){
        var all=c.querySelectorAll('*');
        for(var k=0;k<all.length;k++){
          var l=all[k];
          if(l.childElementCount) continue;
          var s=seconds(l.textContent);
          if(s>=0) return s<=MAX;
        }
        return false;
      }
      function stats(){
        return {items:document.querySelectorAll(VIDEO).length,
                hid:document.querySelectorAll('.ff-hide').length, loads:loads, sweeps:sweeps};
      }
      window.__ffStats=stats;
      function report(){
        try{
          var s=stats();
          window.webkit.messageHandlers.ff.postMessage('yt loads='+s.loads+' items='+s.items+' hid='+s.hid
            +' sweeps='+s.sweeps+' blockedPlays='+window.__ffBlockedPlays+' last='+lastBlocked);
        }catch(e){}
      }
      function sweep(){
        sweeps++;
        syncPlayClass();
        if(!st.isConnected) (document.head||document.documentElement).appendChild(st);
        var want=new Set();
        document.querySelectorAll('a[href*="/shorts"]').forEach(function(a){ want.add(a.closest(CARD)||a); });
        document.querySelectorAll('ytm-pivot-bar-item-renderer').forEach(function(i){
          if(/^\\s*shorts\\s*$/i.test(i.textContent)) want.add(i);
        });
        document.querySelectorAll(VIDEO).forEach(function(c){ if(isShortCard(c)) want.add(c); });
        document.querySelectorAll('.ff-hide').forEach(function(el){ if(!want.has(el)) el.classList.remove('ff-hide'); });
        want.forEach(function(el){ el.classList.add('ff-hide'); });
        report();
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
      snap.textContent='*{scroll-snap-type:none!important}article.ff-old{display:none!important}';
      // --- Feed: hide posts seen on an earlier visit and posts older than a week ---
      // Seen = at least half on screen for DWELL ms. Only earlier visits hide, so nothing jumps while scrolling.
      var WEEK=7*864e5, DWELL=1000, now=Date.now(), seen={};
      try{ seen=JSON.parse(localStorage.getItem('ffSeen')||'{}')||{}; }catch(e){}
      for(var k in seen) if(now-seen[k]>WEEK) delete seen[k];
      var before=Object.assign({},seen);
      function saveSeen(){ try{ localStorage.setItem('ffSeen',JSON.stringify(seen)); }catch(e){} }
      saveSeen();
      function postId(a){
        var l=a.querySelector('a[href*="/p/"],a[href*="/reel/"]');
        var m=l&&/\\/(?:p|reel)\\/([^\\/?#]+)/.exec(l.getAttribute('href'));
        return m?m[1]:null;
      }
      function tooOld(a){
        var t=a.querySelector('time[datetime]');
        return !!t && now-Date.parse(t.getAttribute('datetime'))>WEEK;
      }
      var timers=new Map(), watched=new WeakSet();
      var io=window.IntersectionObserver ? new IntersectionObserver(function(es){
        es.forEach(function(e){
          var a=e.target;
          if(e.isIntersecting){
            if(!timers.has(a)) timers.set(a,setTimeout(function(){
              var id=postId(a); if(id){ seen[id]=Date.now(); saveSeen(); }
            },DWELL));
          } else { clearTimeout(timers.get(a)); timers.delete(a); }
        });
      },{threshold:0.5}) : null;
      var caught=document.createElement('div');
      caught.id='ff-caughtup';
      caught.textContent='Du bist auf dem neuesten Stand. Keine neuen Beiträge aus den letzten 7 Tagen.';
      caught.style.cssText='position:fixed;left:16px;right:16px;top:40%;padding:16px;border-radius:12px;'
        +'background:#222;color:#fff;font:16px -apple-system,sans-serif;text-align:center;z-index:9999;display:none';
      function feed(){
        if(location.pathname!=='/') { caught.style.display='none'; return; }
        var total=0, shown=0;
        document.querySelectorAll('article').forEach(function(a){
          total++;
          var id=postId(a), old=(id&&before[id])||tooOld(a);
          a.classList.toggle('ff-old',!!old);
          if(!old){ shown++; if(io&&!watched.has(a)){ watched.add(a); io.observe(a); } }
        });
        if(!caught.isConnected) document.documentElement.appendChild(caught);
        caught.style.display=total&&!shown?'block':'none';
      }
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
        feed();
        if(onReel()){
          document.querySelectorAll('a[href*="/reel/"]').forEach(function(a){
            if(new URL(a.href,location.href).pathname!==p) hide(a);
          });
          if(!lock.isConnected) root.appendChild(lock);
        } else if(lock.isConnected){
          lock.remove();
        }
      }
      // --- DM reel viewer: lives inside /direct/t/<id> (no URL change), so lock by gesture ---
      var diag={blocked:0}, startY=0, active=false;
      var gs=document.createElement('style');
      gs.textContent='html.ff-locked,html.ff-locked *{touch-action:none!important;scroll-snap-type:none!important;'
        +'overscroll-behavior:none!important}';
      function bigVideo(){
        var vs=document.querySelectorAll('video');
        for(var i=0;i<vs.length;i++){
          var r=vs[i].getBoundingClientRect();
          if(r.width>=innerWidth*0.8&&r.height>=innerHeight*0.45&&r.bottom>0&&r.top<innerHeight) return vs[i];
        }
        return null;
      }
      function locked(){ var p=location.pathname; return (p.indexOf('/direct/')===0||REEL.test(p))&&!!bigVideo(); }
      window.__ffLocked=locked;
      function chain(el){
        var s=[];
        for(var n=el,i=0;n&&i<5;n=n.parentElement,i++){
          var c=(typeof n.className==='string'&&n.className)?'.'+n.className.split(' ')[0].slice(0,8):'';
          s.push(n.tagName.toLowerCase()+(n.getAttribute('role')?'['+n.getAttribute('role')+']':'')+c);
        }
        return s.join('<');
      }
      function report(){
        try{
          var v=bigVideo(), r=v&&v.getBoundingClientRect();
          var vv=window.visualViewport;
          window.webkit.messageHandlers.ff.postMessage('iw='+innerWidth+' cw='+document.documentElement.clientWidth
            +' sw='+document.documentElement.scrollWidth+' vv='+(vv?Math.round(vv.width)+'@'+vv.scale:'-')
            +' lock='+(locked()?1:0)+' blk='+diag.blocked
            +' vids='+document.querySelectorAll('video').length
            +(v?' big '+Math.round(r.width)+'x'+Math.round(r.height)+' '+chain(v):''));
        }catch(e){}
      }
      var VP='width=device-width,initial-scale=1,minimum-scale=1,maximum-scale=1,user-scalable=no';
      function fixViewport(){
        var m=document.querySelector('meta[name=viewport]');
        if(!m){ m=document.createElement('meta'); m.name='viewport'; document.documentElement.appendChild(m); }
        if(m.content!==VP) m.content=VP;
      }
      function gesture(){
        fixViewport();
        if(!gs.isConnected) document.documentElement.appendChild(gs);
        document.documentElement.classList.toggle('ff-locked',locked());
        report();
      }
      addEventListener('touchstart',function(e){
        startY=e.touches[0].clientY; active=locked();
      },{capture:true,passive:true});
      addEventListener('touchmove',function(e){
        if(active&&Math.abs(e.touches[0].clientY-startY)>8){
          e.preventDefault(); e.stopPropagation(); diag.blocked++; report();
        }
      },{capture:true,passive:false});
      var t; new MutationObserver(function(){ clearTimeout(t); t=setTimeout(function(){ sweep(); gesture(); },50); })
        .observe(document,{childList:true,subtree:true});
      document.addEventListener('DOMContentLoaded',function(){ sweep(); gesture(); });
    })();
    """
}
