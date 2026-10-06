const CACHE = 'adt-v16';

const PRECACHE = [
  '/manifest.json',
  '/images/icon-192.png', '/images/icon-512.png',
  '/images/icon-maskable-192.png', '/images/icon-maskable-512.png', '/images/logo.svg',
  '/404.html', '/500.html', '/502.html', '/503.html'
];

const PAGES = ['/', '/qa', '/sales', '/customers', '/company',
               '/features', '/git-activity', '/crowdin-health', '/servers'];

// Same-origin static files handled by the SW; anything else (logsTail, rest/,
// downloads/, logs/, ...) is dynamic and always goes straight to the network.
const STATIC = /\.(css|js|json|png|jpe?g|gif|svg|ico|webp|woff2?|ttf|html)$/;

// Third-party hosts serving version-pinned assets, safe to serve cache-first.
const CDN_HOSTS = ['cdn.jsdelivr.net', 'cdnjs.cloudflare.com', 'code.jquery.com'];

function putInCache(request, response) {
  if (response && (response.status === 200 || response.type === 'opaque')) {
    var clone = response.clone();
    caches.open(CACHE).then(function(cache) {
      cache.put(request, clone);
    });
  }
  return response;
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
});

self.addEventListener('fetch', function(e) {
  if (e.request.method !== 'GET') return;
  var url = new URL(e.request.url);
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;
  var sameOrigin = url.origin === self.location.origin;

  // Pages: network-first, cached copy only as offline fallback
  if (e.request.mode === 'navigate' || (sameOrigin && PAGES.indexOf(url.pathname) !== -1)) {
    e.respondWith(
      fetch(e.request).then(function(response) {
        return putInCache(e.request, response);
      }).catch(function() {
        return caches.match(e.request).then(function(cached) {
          return cached || caches.match('/404.html').then(function(fb) {
            return fb || new Response('', { status: 408 });
          });
        });
      })
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
