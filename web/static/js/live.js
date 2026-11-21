// The live channel: one WebSocket (/ws) per page, opened when something listens to it. The server pushes a message
// when something happened ({"type":"deployed",...}); adtLive.on(type, fn) listens to one type. "reconnect" is made
// up here: the socket was lost and is back, so what was pushed meanwhile was missed (nothing is stored).
// connected() tells whether the socket is open right now: callers keep a slow timer as a safety net when it is not.
(function() {
  if (!window.WebSocket) { window.adtLive = { on: function() {}, connected: function() { return false; } }; return; }
  var handlers = {}, sock = null, up = false, wasUp = false, quiet = false, delay = 1000, timer = null, closing = false, loggedOut = false;

  function emit(type, msg) {
    (handlers[type] || []).slice().forEach(function(fn) { try { fn(msg); } catch (e) { /* a listener must not stop the others */ } });
  }
  function open() {
    if (sock || timer || loggedOut) return;
    var proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    try { sock = new WebSocket(proto + '//' + location.host + '/ws'); } catch (e) { sock = null; again(); return; }
    sock.onopen = function() {
      up = true;
      delay = 1000;
      if (wasUp && !quiet) emit('reconnect', {});
      quiet = false;
      wasUp = true;
    };
    sock.onmessage = function(m) {
      var msg;
      try { msg = JSON.parse(m.data); } catch (e) { return; }
      if (msg && msg.type === 'logout') { logout(); return; }
      if (msg && typeof msg.type === 'string') emit(msg.type, msg);
    };
    sock.onclose = function(e) {
      var wasOpen = up;
      sock = null;
      up = false;
      // 1000: the server ended the socket on purpose (its maximum lifetime, which makes Apache check the session
      // again): nothing was missed, so the next connection is quiet, and it comes at once. If that attempt fails,
      // the connection that follows is not quiet any more: messages may have been missed meanwhile.
      // 1008: the server refused the session (evicted from /debug-sessions, user blocked): the "logout" message may
      // have been lost, the result is the same
      if (e && e.code === 1008) { logout(); return; }
      quiet = !!e && e.code === 1000 && wasOpen;
      if (quiet) delay = 0;
      if (!closing) again();
    };
  }
  // The session was evicted: leave at once. No reconnection (the server would refuse it) and no more request from this
  // page. The saved pages of this browser are forgotten (service worker), then the page asks for its own URL again:
  // Apache sends an evicted session to the login page. NOT to /logout: that would also end the session of somebody
  // who logged in again in another tab of this browser (the cookie is shared) and whose old tab only wakes up now.
  function logout() {
    if (loggedOut) return;
    loggedOut = true;
    closing = true;
    clearTimeout(timer);
    timer = null;
    if (sock) { try { sock.close(); } catch (e) { /* already closing */ } }
    emit('logout', {});
    try {
      if (navigator.serviceWorker && navigator.serviceWorker.controller) navigator.serviceWorker.controller.postMessage({ action: 'forgetPages' });
    } catch (e) { /* no service worker: nothing saved */ }
    window.location.assign(window.location.href);
  }
  // Back off up to 30 s, with some jitter so that a restarted server is not hit by every tab at once
  function again() {
    if (timer) return;
    timer = setTimeout(function() { timer = null; open(); }, delay * (0.75 + Math.random() * 0.5));
    delay = delay === 0 ? 1000 : Math.min(delay * 2, 30000);
  }
  window.addEventListener('pagehide', function() { closing = true; if (sock) sock.close(); });
  // A page restored from the back/forward cache has lost its socket
  window.addEventListener('pageshow', function(e) { if (e.persisted && closing) { closing = false; open(); } });

  window.adtLive = {
    on: function(type, fn) { (handlers[type] = handlers[type] || []).push(fn); open(); },
    connected: function() { return up; }
  };
})();
