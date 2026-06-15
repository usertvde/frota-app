-- ⚠️ SCRIPT ROBUSTO - Executa em múltiplas fases
-- Execute isto em partes se o script completo falhar

-- ============================================
-- FASE 1: LIMPAR TUDO (Execute primeiro)
-- ============================================

-- Desativar RLS para evitar problemas
ALTER TABLE IF EXISTS public.shift_reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.shifts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profiles DISABLE ROW LEVEL SECURITY;

-- Eliminar triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;

-- Eliminar funções
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.get_email_by_username(TEXT) CASCADE;

-- Eliminar todas as políticas RLS
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('profiles', 'vehicles', 'drivers', 'shifts', 'shift_reports'))
  LOOP
    EXECUTE 'DROP POLICY IF EXISTS "profiles_select" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "profiles_update_self" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "profiles_insert_self" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "vehicles_admin" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "vehicles_driver_select" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "drivers_admin" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "drivers_self_select" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "shifts_admin" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "shifts_driver_select" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "shift_reports_admin" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
    EXECUTE 'DROP POLICY IF EXISTS "shift_reports_driver_select" ON ' || r.schemaname || '.' || r.tablename || ' CASCADE';
  END LOOP;
END $$;

-- Eliminar tabelas (ordem reversa de dependências)
DROP TABLE IF EXISTS public.shift_reports CASCADE;
DROP TABLE IF EXISTS public.shifts CASCADE;
DROP TABLE IF EXISTS public.drivers CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- ============================================
-- FASE 2: CRIAR TABELAS BASE
-- ============================================

-- Tabela 1: profiles (sem dependências externas, apenas de auth.users)
CREATE TABLE public.profiles (
  user_id UUID NOT NULL PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  username TEXT UNIQUE,
  role TEXT NOT NULL DEFAULT 'driver' CHECK (role IN ('admin', 'driver')),
  full_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela 2: vehicles (sem dependências internas)
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

-- Tabela 3: drivers (depende apenas de auth.users, não de profiles)
CREATE TABLE public.drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  full_name TEXT,
  access_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- FASE 3: CRIAR TABELAS DEPENDENTES
-- ============================================

-- Tabela 4: shifts (depende de drivers e vehicles)
CREATE TABLE public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.drivers (id) ON DELETE CASCADE,
  vehicle_id UUID NOT NULL REFERENCES public.vehicles (id) ON DELETE CASCADE,
  shift_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela 5: shift_reports (depende de shifts e drivers)
CREATE TABLE public.shift_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_id UUID NOT NULL REFERENCES public.shifts (id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES public.drivers (id) ON DELETE CASCADE,
  start_location TEXT,
  end_location TEXT,
  distance_km DECIMAL(10, 2),
  fuel_consumed DECIMAL(10, 2),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- FASE 4: CRIAR ÍNDICES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_drivers_user_id ON public.drivers(user_id);
CREATE INDEX IF NOT EXISTS idx_shifts_driver_id ON public.shifts(driver_id);
CREATE INDEX IF NOT EXISTS idx_shifts_vehicle_id ON public.shifts(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_shifts_date ON public.shifts(shift_date);
CREATE INDEX IF NOT EXISTS idx_shift_reports_shift_id ON public.shift_reports(shift_id);
CREATE INDEX IF NOT EXISTS idx_shift_reports_driver_id ON public.shift_reports(driver_id);

-- ============================================
-- FASE 5: ATIVAR ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_reports ENABLE ROW LEVEL SECURITY;

-- ============================================
-- FASE 6: CRIAR POLÍTICAS RLS
-- ============================================

-- Políticas para profiles
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "profiles_select_admin" ON public.profiles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  );

CREATE POLICY "profiles_update_self" ON public.profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Políticas para vehicles
CREATE POLICY "vehicles_admin_all" ON public.vehicles
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "vehicles_driver_read" ON public.vehicles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'driver')
  );

-- Políticas para drivers
CREATE POLICY "drivers_admin_all" ON public.drivers
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "drivers_self_read" ON public.drivers
  FOR SELECT USING (user_id = auth.uid());

-- Políticas para shifts
CREATE POLICY "shifts_admin_all" ON public.shifts
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "shifts_driver_read" ON public.shifts
  FOR SELECT USING (
    driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

-- Políticas para shift_reports
CREATE POLICY "shift_reports_admin_all" ON public.shift_reports
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "shift_reports_driver_read" ON public.shift_reports
  FOR SELECT USING (
    driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

-- ============================================
-- FASE 7: CRIAR FUNÇÕES E TRIGGERS
-- ============================================

-- Função para criar perfil automaticamente
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, role)
  VALUES (new.id, new.email, 'driver')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger para novos utilizadores
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Função para obter email por username
CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username TEXT)
RETURNS TEXT AS $$
DECLARE
  v_email TEXT;
BEGIN
  SELECT email INTO v_email FROM public.profiles WHERE username = p_username LIMIT 1;
  RETURN v_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================
-- ✅ SETUP CONCLUÍDO!
-- ============================================

-- Agora crie um utilizador admin com este comando:
-- UPDATE public.profiles SET role = 'admin', username = 'admin' WHERE email = 'seu_email@example.com';

-- Verifique se tudo foi criado:
-- SELECT * FROM public.profiles;
-- SELECT * FROM public.vehicles;
-- SELECT * FROM public.drivers;
-- SELECT * FROM public.shifts;
-- SELECT * FROM public.shift_reports;
