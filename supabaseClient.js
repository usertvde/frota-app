/* =============================================
   SUPABASE CLIENT CONFIGURATION
   ============================================= */

// Substitua pelos dados do seu projeto Supabase se forem diferentes
const SUPABASE_URL = "https://oaztprykumrbubqxjkmb.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9henRwcnlrdW1yYnVicXhqa21iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyNzk2NzYsImV4cCI6MjA5Njg1NTY3Nn0.dywR3Xt1Dv4w5nR1tjKkNnW3_v9muGmgT8Tr4ug6jCk";

// URL da sua Edge Function (Certifique-se que o nome da função no Supabase coincide)
const EDGE_FUNCTION_URL = "https://oaztprykumrbubqxjkmb.supabase.co/functions/v1/clever-processor";

// Inicialização do Cliente
window.supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
window.EDGE_FUNCTION_URL = EDGE_FUNCTION_URL;

console.log('SaaS: Supabase Client inicializado com isolamento de empresa.');