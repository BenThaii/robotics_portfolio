/* site.js — shared behaviour for every page: quiet mobile menu, nav colour
   over the light index footer, in-view autoplay for muted loops, and a subtle
   reveal. Everything degrades gracefully: no JS = all content visible. */
(function(){
  var reduced = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* --- mobile menu ------------------------------------------------------ */
  var toggle = document.querySelector('.nav__toggle');
  var menu   = document.querySelector('.nav__menu');
  if(toggle && menu){
    toggle.addEventListener('click', function(){
      var open = menu.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    menu.addEventListener('click', function(e){
      if(e.target.closest('a')){
        menu.classList.remove('is-open');
        toggle.setAttribute('aria-expanded','false');
      }
    });
  }

  /* --- nav text colour over the light index ------------------------------ */
  var nav   = document.querySelector('.nav');
  var index = document.querySelector('.index');
  function navColor(){
    if(!nav || !index) return;
    var r = index.getBoundingClientRect();
    nav.classList.toggle('is-dark', r.top <= 74 && r.bottom > 0);
  }
  if(nav && index){
    window.addEventListener('scroll', navColor, {passive:true});
    window.addEventListener('resize', navColor);
    navColor();
  }

  /* --- muted loop videos: optional clean in/out window, play in view ----- */
  var vids = Array.prototype.slice.call(document.querySelectorAll('video[loop][muted]'));
  vids.forEach(function(v){
    var start = parseFloat(v.getAttribute('data-start') || '0');
    var end   = parseFloat(v.getAttribute('data-end')   || '0');
    var seeked = false;
    function seek(){
      if(start > 0 && !seeked && v.readyState >= 1){ v.currentTime = start; seeked = true; }
    }
    v.addEventListener('loadedmetadata', seek);
    seek();
    if(start > 0 || end > 0){
      v.addEventListener('timeupdate', function(){
        if(start > 0 && v.currentTime < start - 0.2) v.currentTime = start;
        if(end > start && v.currentTime >= end) v.currentTime = start;
      });
    }
  });

  function playInView(){
    vids.forEach(function(v){
      var r = v.getBoundingClientRect();
      var inView = r.top < innerHeight * 0.92 && r.bottom > innerHeight * 0.08;
      if(inView && !reduced && !document.hidden){
        if(v.paused){ v.play().catch(function(){}); }
      } else if(!inView && !v.paused){ v.pause(); }
    });
  }
  if('IntersectionObserver' in window){
    var io = new IntersectionObserver(playInView, {threshold:.35});
    vids.forEach(function(v){ io.observe(v); });
  }
  document.addEventListener('visibilitychange', function(){ if(!document.hidden){ playInView(); } });
  window.addEventListener('pageshow', playInView);
  setInterval(playInView, 2500);
  playInView();

  /* --- subtle reveal (added at runtime so no-JS stays fully visible) ---- */
  if(!reduced && 'IntersectionObserver' in window){
    var targets = document.querySelectorAll('[data-reveal]');
    targets.forEach(function(t){ t.classList.add('reveal'); });
    var ro = new IntersectionObserver(function(entries){
      entries.forEach(function(en){
        if(en.isIntersecting){ en.target.classList.add('in'); ro.unobserve(en.target); }
      });
    }, {threshold:.08});
    targets.forEach(function(t){ ro.observe(t); });
    requestAnimationFrame(function(){
      targets.forEach(function(t){
        var r = t.getBoundingClientRect();
        if(r.top < innerHeight && r.bottom > 0){ t.classList.add('in'); }
      });
    });
  }
})();
