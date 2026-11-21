// The service worker (sw.js) shows the copy it kept of a page when the server is down or unreachable, and marks it
// with <meta name="adt-offline" content="date the server sent it">. This says so on the page, and brings the live
// page back as soon as the server answers: the live socket (live.js) says hello, or the browser reports the network
// is back.
(function() {
  var mark = document.querySelector('meta[name="adt-offline"]');
  if (!mark) return;
  function reload() { window.location.reload(); }

  function bar() {
    var when = new Date(mark.content);
    var el = document.createElement('div');
    el.className = 'offline-bar';
    el.setAttribute('role', 'status');
    var text = document.createElement('span');
    text.textContent = 'The server cannot be reached: this is a saved copy' +
      (isNaN(when) ? '' : ' from ' + when.toLocaleString()) + '. It is not updated.';
    var retry = document.createElement('button');
    retry.type = 'button';
    retry.className = 'btn btn-sm btn-outline-light';
    retry.textContent = 'Try again';
    retry.addEventListener('click', reload);
    el.appendChild(text);
    el.appendChild(retry);
    document.body.insertBefore(el, document.body.firstChild);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bar); else bar();

  window.addEventListener('online', reload);
  if (window.adtLive) window.adtLive.on('hello', reload);
})();
