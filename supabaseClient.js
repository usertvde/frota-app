const SUPABASE_URL = "https://oaztprykumrbubqxjkmb.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9henRwcnlrdW1yYnVicXhqa21iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyNzk2NzYsImV4cCI6MjA5Njg1NTY3Nn0.dywR3Xt1Dv4w5nR1tjKkNnW3_v9muGmgT8Tr4ug6jCk";
const EDGE_FUNCTION_URL = "https://oaztprykumrbubqxjkmb.supabase.co/functions/v1/manage-users"; // Substitui pelo teu URL real da Edge Function

// Criar o cliente Supabase
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);