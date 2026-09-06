const CACHE_NAME = 'swasthyasetu-v2';
const LOCAL_ASSETS = [
    './',
    './index.html',
    './style.css',
    './script.js',
    './risk-engine.js',
    './corpus.js',
    './manifest.json'
];

const CDN_ASSETS = [
    'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600&display=swap',
    'https://cdn.jsdelivr.net/npm/chart.js',
    'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js'
];

const ALL_ASSETS = [...LOCAL_ASSETS, ...CDN_ASSETS];

// Install: pre-cache all assets
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME).then(cache => {
            // Cache local assets (must succeed), CDN assets best-effort
            return cache.addAll(LOCAL_ASSETS).then(() => {
                return Promise.allSettled(
                    CDN_ASSETS.map(url => cache.add(url).catch(err => {
                        console.warn('[SW] Failed to cache CDN asset:', url, err);
                    }))
                );
            });
        })
    );
    self.skipWaiting();
});

// Activate: purge old caches
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(keys => {
            return Promise.all(
                keys.map(key => {
                    if (key !== CACHE_NAME) {
                        console.log('[SW] Purging old cache:', key);
                        return caches.delete(key);
                    }
                })
            );
        })
    );
    self.clients.claim();
});

// Fetch: cache-first for local, stale-while-revalidate for CDN
self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);
    const isLocal = url.origin === self.location.origin;

    if (isLocal) {
        // Cache-first for local assets
        event.respondWith(
            caches.match(event.request).then(cached => {
                return cached || fetch(event.request).then(response => {
                    // Cache dynamically fetched local assets (e.g. images)
                    if (response.ok) {
                        const clone = response.clone();
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
                    }
                    return response;
                }).catch(() => {
                    // Offline fallback for navigation
                    if (event.request.destination === 'document') {
                        return caches.match('./index.html');
                    }
                });
            })
        );
    } else {
        // Stale-while-revalidate for CDN resources
        event.respondWith(
            caches.match(event.request).then(cached => {
                const fetchPromise = fetch(event.request).then(response => {
                    if (response.ok) {
                        const clone = response.clone();
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
                    }
                    return response;
                }).catch(() => cached);

                return cached || fetchPromise;
            })
        );
    }
});
