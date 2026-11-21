const CACHE = 'adt-v35';

const PRECACHE = [
  '/manifest.json', '/offline.html',
  '/images/icon-192.png', '/images/icon-512.png',
  '/images/icon-maskable-192.png', '/images/icon-maskable-512.png', '/images/logo.svg',
  // not the 403 page: it is answered by the application with the 403 status (addAll would refuse it) and differs per visitor
  '/errors/frontend/404.html', '/errors/frontend/500.html', '/errors/frontend/502.html', '/errors/frontend/503.html'
];

const PAGES = ['/', '/qa', '/sales', '/customers', '/company',
               '/features', '/git-activity', '/crowdin-health', '/servers'];

// Same-origin static files handled by the SW; anything else (logsTail, rest/,
// downloads/, logs/, ...) is dynamic and always goes straight to the network.
const STATIC = /\.(css|js|json|png|jpe?g|gif|svg|ico|webp|woff2?|ttf|html)$/;

// Third-party hosts serving version-pinned assets, safe to serve cache-first.
const CDN_HOSTS = ['cdn.jsdelivr.net', 'cdnjs.cloudflare.com'];

function putInCache(request, response) {
  // not a redirected answer: with an expired session the file would be the login page, kept under the URL of a script
  if (response && !response.redirected && (response.status === 200 || response.type === 'opaque')) {
    var clone = response.clone();
    caches.open(CACHE).then(function(cache) {
      return cache.put(request, clone).then(function() { return dropOlderVersions(cache, request); });
    }).catch(function() {}); // quota exceeded or a request the Cache API refuses: the page works without it
  }
  return response;
}

// /style.css?v=1 and /js/head.js?v=1 are replaced by their ?v=2 once a new version is deployed: keep only the latest
function dropOlderVersions(cache, request) {
  var url = new URL(request.url);
  if (url.origin !== self.location.origin || !url.searchParams.has('v')) return null;
  return cache.keys().then(function(keys) {
    return Promise.all(keys.filter(function(k) {
      var u = new URL(k.url);
      return u.pathname === url.pathname && u.search !== url.search && u.searchParams.has('v');
    }).map(function(k) { return cache.delete(k); }));
  });
}

// The dashboard pages are kept only to be shown offline: the plain page URL, and neither a redirect
// (the login form answered in its place) nor any other page (debug, logs, edit forms, query strings),
// which hold session data and would grow the cache without bound.
function cacheablePage(url, response) {
  return url.origin === self.location.origin && PAGES.indexOf(url.pathname) !== -1 && !url.search &&
    response.status === 200 && response.type === 'basic' && !response.redirected;
}

// Served instead of a page that cannot be fetched (server down, network lost)
const OFFLINE = '/offline.html';

// The copy of a dashboard page kept for the offline case, marked as such: a <meta name="adt-offline"> carrying the
// date the server sent it (js/offline.js shows the banner and goes back to the live page once the server answers).
function offlineCopy(cached) {
  var date = cached.headers.get('Date') || '';
  if (!/^[A-Za-z0-9 ,:+-]{1,40}$/.test(date)) date = '';
  return cached.text().then(function(html) {
    var meta = '<meta name="adt-offline" content="' + date + '">';
    var marked = html.replace(/<head[^>]*>/i, function(h) { return h + meta; });
    var headers = new Headers(cached.headers);
    // the body is the decoded text, with another length
    headers.delete('Content-Length');
    headers.delete('Content-Encoding');
    return new Response(marked, { status: 200, statusText: 'OK', headers: headers });
  });
}

// What a page request gets when the network failed (failure is null) or the proxy answered 502/503/504 because
// adt-web is down (failure is that answer): the copy kept of the page, else the error the proxy sent, else the
// offline page (navigations only: a script asking for a page must not receive HTML it did not ask for)
function offlineFallback(request, url, failure) {
  return caches.match(request).then(function(cached) {
    if (cached && cacheablePage(url, cached)) return offlineCopy(cached);
    if (failure) return failure;
    if (request.mode !== 'navigate') return new Response('', { status: 408 });
    return caches.match(OFFLINE).then(function(page) { return page || new Response('', { status: 408 }); });
  });
}

// Removes the saved pages (they show the name and the menu of the person who was signed in)
function forgetPages() {
  return caches.open(CACHE).then(function(cache) {
    return cache.keys().then(function(keys) {
      return Promise.all(keys.filter(function(r) {
        return PAGES.indexOf(new URL(r.url).pathname) !== -1;
      }).map(function(r) { return cache.delete(r); }));
    });
  });
}

self.addEventListener('install', function(e) {
  e.waitUntil(
    caches.open(CACHE).then(function(cache) {
      // Bypass the HTTP cache so a new SW never precaches stale copies
      return cache.addAll(PRECACHE.map(function(url) {
        return new Request(url, { cache: 'reload' });
      }));
    })
  );
});

self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.filter(function(k) { return k !== CACHE; }).map(function(k) {
        return caches.delete(k);
      }));
    }).then(function() { return self.clients.claim(); })
  );
});

self.addEventListener('message', function(e) {
  if (e.data && e.data.action === 'skipWaiting') {
    self.skipWaiting();
  }
  // The session ended (evicted from /debug-sessions): the pages of this person are not kept for the next visitor
  if (e.data && e.data.action === 'forgetPages') {
    e.waitUntil(forgetPages());
  }
});

self.addEventListener('fetch', function(e) {
  if (e.request.method !== 'GET') return;
  var url = new URL(e.request.url);
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;
  var sameOrigin = url.origin === self.location.origin;

  // The deployment event stream stays open: never through the cache
  if (sameOrigin && url.pathname === '/events') return;

  // Signing out removes the pages the previous visitor saw. So does the login page: it is shown when a session expired
  // or was never closed (nobody pressed Logout), and the next person to sign in on this browser must not be offered the
  // saved dashboard of the previous one when the server is down
  if (sameOrigin && (url.pathname === '/logout' || (url.pathname === '/login' && e.request.mode === 'navigate'))) e.waitUntil(forgetPages());

  // Pages: network-first, the kept copy when the server cannot be reached
  if (e.request.mode === 'navigate' || (sameOrigin && PAGES.indexOf(url.pathname) !== -1)) {
    e.respondWith(
      fetch(e.request).then(function(response) {
        // Apache answers 502/503/504 while adt-web is down: that is not a page to show instead of the kept copy
        if (response.status >= 502 && response.status <= 504 && sameOrigin) return offlineFallback(e.request, url, response);
        return cacheablePage(url, response) ? putInCache(e.request, response) : response;
      }).catch(function() { return offlineFallback(e.request, url, null); })
    );
    return;
  }

  // Version-pinned CDN assets: cache-first
  if (CDN_HOSTS.indexOf(url.hostname) !== -1) {
    e.respondWith(
      caches.match(e.request).then(function(cached) {
        return cached || fetch(e.request).then(function(response) {
          return putInCache(e.request, response);
        });
      })
    );
    return;
  }

  // Same-origin static files: stale-while-revalidate. The revalidation skips
  // the HTTP cache freshness (cheap 304 when unchanged) so updates show up on
  // the next load instead of after the Apache Expires delay.
  if (sameOrigin && STATIC.test(url.pathname)) {
    e.respondWith(
      caches.match(e.request).then(function(cached) {
        var fetched = fetch(e.request, { cache: 'no-cache' }).then(function(response) {
          return putInCache(e.request, response);
        }).catch(function() {
          return cached || new Response('', { status: 408 });
        });
        if (cached) {
          e.waitUntil(fetched);
          return cached;
        }
        return fetched;
      })
    );
  }
});
