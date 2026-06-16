const CACHE_NAME = 'frota-v3';
const urlsToCache = [
  '/',
  '/index.html',
  '/admin.html',
  '/driver.html',
  '/style.css',
  '/supabaseClient.js',
  '/manifest.json'
];

// Instalar o Service Worker e guardar em cache
self.addEventListener('install', event => {
  console.log('Service Worker a instalar...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('Cache aberto');
        return cache.addAll(urlsToCache);
      })
      .then(() => self.skipWaiting())
  );
});

// Ativar o Service Worker e limpar caches antigos
self.addEventListener('activate', event => {
  console.log('Service Worker ativado');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.filter(cacheName => cacheName !== CACHE_NAME)
          .map(cacheName => caches.delete(cacheName))
      );
    }).then(() => self.clients.claim())
  );
});

// Estratégia de cache: Network First, depois cache
self.addEventListener('fetch', event => {
  // Ignorar pedidos à API do Supabase
  if (event.request.url.includes('supabase.co')) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then(response => {
        // Guardar em cache se a resposta for válida
        if (response && response.status === 200 && response.type === 'basic') {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(event.request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // Se a rede falhar, tentar servir da cache
        return caches.match(event.request);
      })
  );
});