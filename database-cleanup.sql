-- 🧹 SCRIPT DE LIMPEZA - Execute isto PRIMEIRO
-- Executa em Supabase SQL Editor para remover tudo e começar do zero

-- Desabilitar RLS em todas as tabelas
ALTER TABLE IF EXISTS public.shift_reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.shifts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.driver_availability DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profiles DISABLE ROW LEVEL SECURITY;

-- Eliminar todos os triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;

-- Eliminar todas as funções
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.get_email_by_username(text) CASCADE;

-- Eliminar todas as políticas RLS (para limpar completamente)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT schemaname, tablename, policyname 
    FROM pg_policies 
    WHERE schemaname = 'public'
  )
  LOOP
    EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
  END LOOP;
END $$;

-- Eliminar todas as tabelas (ordem reversa de dependências)
DROP TABLE IF EXISTS public.shift_reports CASCADE;
DROP TABLE IF EXISTS public.shifts CASCADE;
DROP TABLE IF EXISTS public.driver_availability CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- ✅ Limpeza completa feita!
-- Agora execute: database-simple-setup.sql
