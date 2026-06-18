/* =============================================
   SERVICE WORKER - GESTÃO DE FROTA (SaaS v5)
   ============================================= */

const CACHE_NAME = 'frota-v5'; // Incrementado para v5 para forçar atualização SaaS
const urlsToCache = [
  '/',
  '/index.html',
  '/admin.html',
  '/driver.html',
  '/superadmin.html', // Novo painel adicionado à cache
  '/style.css',
  '/supabaseClient.js',
  '/manifest.json'
];

// 1. Instalação: Guarda os ficheiros essenciais na cache
self.addEventListener('install', event => {
  console.log('SW: A instalar nova versão v5...');
  // Força o novo service worker a tornar-se ativo imediatamente
  self.skipWaiting(); 
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('SW: Cache aberta e ficheiros mapeados.');
        return cache.addAll(urlsToCache);
      })
  );
});

// 2. Ativação: Limpa caches de versões anteriores para evitar conflitos
self.addEventListener('activate', event => {
  console.log('SW: Ativado. A limpar caches antigas...');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.filter(name => name !== CACHE_NAME)
          .map(name => {
            console.log('SW: A apagar cache obsoleta:', name);
            return caches.delete(name);
          })
      );
    }).then(() => self.clients.claim()) // Assume o controlo de todas as abas abertas
  );
});

// 3. Interceção de Pedidos (Fetch)
self.addEventListener('fetch', event => {
  // Ignorar pedidos para a API do Supabase (dados em tempo real) e extensões
  if (event.request.url.includes('supabase.co') || event.request.url.startsWith('chrome-extension')) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then(response => {
        // Se a resposta for válida, guarda uma cópia na cache
        if (response && response.status === 200 && response.type === 'basic') {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(event.request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // Se a rede falhar (offline), tenta servir a partir da cache
        return caches.match(event.request);
      })
  );
});