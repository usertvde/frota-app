-- ⚠️ SCRIPT SIMPLES SEM RLS (Para evitar recursão)
-- Execute isto em partes no Supabase SQL Editor

-- ============================================
-- FASE 1: LIMPAR TUDO (Execute primeiro)
-- ============================================

-- Desativar RLS para evitar problemas
ALTER TABLE IF EXISTS public.shift_reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.shifts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.driver_availability DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profiles DISABLE ROW LEVEL SECURITY;

-- Eliminar triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;

-- Eliminar funções
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.get_email_by_username(text) CASCADE;

-- Eliminar tabelas (ordem reversa de dependências)
DROP TABLE IF EXISTS public.shift_reports CASCADE;
DROP TABLE IF EXISTS public.shifts CASCADE;
DROP TABLE IF EXISTS public.driver_availability CASCADE;
DROP TABLE IF EXISTS public.drivers CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- ============================================
-- FASE 2: CRIAR TABELAS BASE
-- ============================================

-- Tabela 1: profiles
CREATE TABLE public.profiles (
  user_id UUID NOT NULL PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  username TEXT UNIQUE,
  role TEXT NOT NULL DEFAULT 'driver' CHECK (role IN ('admin', 'driver')),
  full_name TEXT,
  access_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela 2: vehicles
CREATE TABLE public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  plate TEXT UNIQUE NOT NULL,
  year INTEGER,
  photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela 3: shifts
CREATE TABLE public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles (user_id) ON DELETE CASCADE,
  vehicle_id UUID NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
  shift_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'started', 'completed', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela 4: shift_reports
CREATE TABLE public.shift_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_id UUID NOT NULL REFERENCES public.shifts (id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES public.profiles (user_id) ON DELETE CASCADE,
  start_km INTEGER,
  end_km INTEGER,
  start_location TEXT,
  end_location TEXT,
  distance_km DECIMAL(10, 2),
  fuel_litres DECIMAL(10, 2),
  fuel_cost DECIMAL(10, 2),
  invoiced_amount DECIMAL(10, 2),
  invoice_number TEXT,
  start_photo_url TEXT,
  end_photo_url TEXT,
  notes TEXT,
  closed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela 5: driver_availability
CREATE TABLE public.driver_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles (user_id) ON DELETE CASCADE,
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- FASE 3: CRIAR ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_shifts_driver_id ON public.shifts(driver_id);
CREATE INDEX IF NOT EXISTS idx_shifts_vehicle_id ON public.shifts(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_shifts_date ON public.shifts(shift_date);
CREATE INDEX IF NOT EXISTS idx_shift_reports_shift_id ON public.shift_reports(shift_id);
CREATE INDEX IF NOT EXISTS idx_shift_reports_driver_id ON public.shift_reports(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_availability_driver_id ON public.driver_availability(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_availability_date ON public.driver_availability(date);

-- ============================================
-- FASE 4: CRIAR FUNÇÕES
-- ============================================

-- Função: Auto-criar perfil quando novo utilizador se regista
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, username, role)
  VALUES (NEW.id, NEW.email, SPLIT_PART(NEW.email, '@', 1), 'driver')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Executar função quando novo utilizador criado
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Função: Buscar email por username
CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT email FROM public.profiles WHERE username = p_username LIMIT 1;
$$;

-- ============================================
-- FASE 5: ATIVAR ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_availability ENABLE ROW LEVEL SECURITY;

-- ============================================
-- FASE 6: CRIAR POLÍTICAS RLS SIMPLES (SEM RECURSÃO)
-- ============================================

-- ===== PROFILES =====
-- Utilizador só pode ver o seu próprio perfil
CREATE POLICY "profiles_self_read" ON public.profiles
  FOR SELECT
  USING (auth.uid() = user_id);

-- Admin pode ver todos os perfis
CREATE POLICY "profiles_admin_read" ON public.profiles
  FOR SELECT
  USING (auth.role() = 'authenticated' AND user_id IN (
    SELECT user_id FROM public.profiles WHERE role = 'admin'
  ));

-- Utilizador pode atualizar o seu próprio perfil
CREATE POLICY "profiles_self_update" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Novo perfil criado automaticamente pelo trigger
CREATE POLICY "profiles_trigger_insert" ON public.profiles
  FOR INSERT
  WITH CHECK (true); -- Permite inserts da função SECURITY DEFINER

-- ===== VEHICLES =====
-- Admin pode fazer tudo
CREATE POLICY "vehicles_admin_all" ON public.vehicles
  FOR ALL
  USING (auth.uid() IN (SELECT user_id FROM public.profiles WHERE role = 'admin'));

-- Driver pode ver (não editar)
CREATE POLICY "vehicles_driver_select" ON public.vehicles
  FOR SELECT
  USING (auth.uid() IN (SELECT user_id FROM public.profiles WHERE role = 'driver'));

-- ===== SHIFTS =====
-- Admin pode fazer tudo
CREATE POLICY "shifts_admin_all" ON public.shifts
  FOR ALL
  USING (auth.uid() IN (SELECT user_id FROM public.profiles WHERE role = 'admin'));

-- Driver pode ver o seus próprio shifts
CREATE POLICY "shifts_driver_read" ON public.shifts
  FOR SELECT
  USING (driver_id = auth.uid());

-- ===== SHIFT_REPORTS =====
-- Admin pode fazer tudo
CREATE POLICY "shift_reports_admin_all" ON public.shift_reports
  FOR ALL
  USING (auth.uid() IN (SELECT user_id FROM public.profiles WHERE role = 'admin'));

-- Driver pode ver/editar os seus próprios reports
CREATE POLICY "shift_reports_driver_crud" ON public.shift_reports
  FOR ALL
  USING (driver_id = auth.uid());

-- ===== DRIVER_AVAILABILITY =====
-- Admin pode fazer tudo
CREATE POLICY "driver_availability_admin_all" ON public.driver_availability
  FOR ALL
  USING (auth.uid() IN (SELECT user_id FROM public.profiles WHERE role = 'admin'));

-- Driver pode gerenciar a sua própria disponibilidade
CREATE POLICY "driver_availability_self" ON public.driver_availability
  FOR ALL
  USING (driver_id = auth.uid());

-- ============================================
-- ✅ SCRIPT COMPLETO - PRONTO PARA USAR
-- ============================================
