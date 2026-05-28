var CACHE = 'adt-v1';

var PRECACHE_URLS = [
  '/',
  '/style.css',
  '/images/favicon.ico',
  '/images/icon-192.png',
  '/images/icon-512.png',
  '/images/icon.svg',
  '/images/icon-maskable.svg',
  '/manifest.json'
];

var RUNTIME_CACHE_HOSTS = [
  'cdn.jsdelivr.net',
  'cdnjs.cloudflare.com',
  'code.jquery.com'
];

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE).then(function(cache) {
      return cache.addAll(PRECACHE_URLS);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.filter(function(k) { return k !== CACHE; }).map(function(k) { return caches.delete(k); })
      );
    })
  );
  self.clients.claim();
});

function isNavigationRequest(request) {
  return request.mode === 'navigate' ||
    (request.method === 'GET' && request.headers.get('Accept') && request.headers.get('Accept').indexOf('text/html') !== -1);
}

function isCDNRequest(url) {
  return RUNTIME_CACHE_HOSTS.some(function(host) { return url.hostname.indexOf(host) !== -1; });
}

self.addEventListener('fetch', function(event) {
  var url = new URL(event.request.url);

  if (url.origin !== self.location.origin && !isCDNRequest(url)) {
    return;
  }

  if (isNavigationRequest(event.request)) {
    event.respondWith(
      fetch(event.request).catch(function() {
        return caches.match('/');
      })
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then(function(cached) {
      var fetchPromise = fetch(event.request).then(function(response) {
        if (response && response.status === 200 && response.type === 'basic' && event.request.method === 'GET') {
          var copy = response.clone();
          caches.open(CACHE).then(function(cache) { cache.put(event.request, copy); });
        }
        if (isCDNRequest(url) && response && response.status === 200 && event.request.method === 'GET') {
          var copy = response.clone();
          caches.open(CACHE).then(function(cache) { cache.put(event.request, copy); });
        }
        return response;
      }).catch(function() {
        return cached || new Response('Offline', { status: 503 });
      });
      return cached || fetchPromise;
    })
  );
});
