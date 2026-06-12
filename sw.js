const CACHE_NAME = 'frota-v2';
const urlsToCache = [
  '/',
  '/login.html',
  '/admin.html',
  '/driver.html',
  '/style.css',
  '/app.js',
  '/supabaseClient.js',
  '/manifest.json'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request).then(response => response || fetch(event.request))
  );
});