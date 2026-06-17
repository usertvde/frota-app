const CACHE_NAME = 'frota-v4';
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
  console.log('Service Worker a instalar a versão v4...');
  // Força o novo service worker a assumir o controlo imediatamente
  self.skipWaiting(); 
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('Cache aberto e ficheiros guardados.');
        return cache.addAll(urlsToCache);
      })
  );
});

// Ativar o Service Worker e limpar caches antigas
self.addEventListener('activate', event => {
  console.log('Service Worker ativado. A limpar versões antigas...');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.filter(cacheName => cacheName !== CACHE_NAME)
          .map(cacheName => {
            console.log('A apagar cache antiga:', cacheName);
            return caches.delete(cacheName);
          })
      );
    }).then(() => self.clients.claim()) // Assume o controlo de todas as páginas abertas
  );
});

// Estratégia de cache: Network First (Tenta a internet primeiro, se falhar usa a cache)
self.addEventListener('fetch', event => {
  // Ignorar pedidos à API do Supabase (dados em tempo real) e extensões do browser
  if (event.request.url.includes('supabase.co') || event.request.url.startsWith('chrome-extension')) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then(response => {
        // Se a resposta for válida, atualiza a cache silenciosamente
        if (response && response.status === 200 && response.type === 'basic') {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(event.request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // Se estiver offline ou a rede falhar, vai buscar à cache
        console.log('Modo offline: a carregar da cache ->', event.request.url);
        return caches.match(event.request);
      })
  );
});