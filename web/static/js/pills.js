// Every title="" of the pages shows as a pill, like the rel="tooltip" ones, instead of the browser's own tooltip.
//
// A Bootstrap tooltip is made for an element the first time the pointer or the focus reaches it (a delegated listener):
// the elements the pages create or swap in later (see autorefresh.js) need no list to keep up to date. Bootstrap takes the
// title away from the element (the browser then shows nothing of its own) and gives an icon-only element the text as its
// accessible name. Only where a pointer hovers: on a touch screen a tap would leave the pill on screen, so the browser
// keeps what it does there (nothing). Without Bootstrap (its CDN is unreachable) the browser's tooltips stay.
(function() {
  if (!window.matchMedia || !window.matchMedia('(hover: hover)').matches) return;
  // Not elements whose title is not a tooltip (a frame's name, an SVG), nor popovers, nor what asks to keep the browser's own
  var SKIP = 'html, body, iframe, svg, link, meta, [rel=popover], [data-no-pill]';

  function pill(e) {
    if (typeof bootstrap === 'undefined' || !e.target || !e.target.closest) return;
    var el = e.target.closest('[title]');
    var title = el && el.getAttribute('title');
    if (!title || el.matches(SKIP)) return;
    // The page changed the title of an element that already has its tooltip (a button that says something else now):
    // dispose gives the old text back as the title, so the new one is put back before the tooltip is made again
    var old = bootstrap.Tooltip.getInstance(el);
    if (old) { old.dispose(); el.setAttribute('title', title); }
    new bootstrap.Tooltip(el, { container: 'body', trigger: 'hover focus' }).show();
  }
  document.addEventListener('mouseover', pill);
  document.addEventListener('focusin', pill);
})();
