-- ⚠️ SCRIPT DE LIMPEZA E SETUP COMPLETO
-- Execute este script se o anterior teve erros

-- PASSO 1: Desativar RLS temporariamente para evitar erros de constraint
ALTER TABLE IF EXISTS public.shift_reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.shifts DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.drivers DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vehicles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profiles DISABLE ROW LEVEL SECURITY;

-- PASSO 2: Eliminar triggers e funções antigos
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.get_email_by_username(TEXT) CASCADE;

-- PASSO 3: Eliminar políticas RLS antigas
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_self" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_self" ON public.profiles;
DROP POLICY IF EXISTS "vehicles_admin" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_driver_select" ON public.vehicles;
DROP POLICY IF EXISTS "drivers_admin" ON public.drivers;
DROP POLICY IF EXISTS "drivers_self_select" ON public.drivers;
DROP POLICY IF EXISTS "shifts_admin" ON public.shifts;
DROP POLICY IF EXISTS "shifts_driver_select" ON public.shifts;
DROP POLICY IF EXISTS "shift_reports_admin" ON public.shift_reports;
DROP POLICY IF EXISTS "shift_reports_driver_select" ON public.shift_reports;

-- PASSO 4: Eliminar tabelas antigas (se existirem)
-- Ordem inversa de dependências
DROP TABLE IF EXISTS public.shift_reports CASCADE;
DROP TABLE IF EXISTS public.shifts CASCADE;
DROP TABLE IF EXISTS public.drivers CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- PASSO 5: Criar tabelas do zero
CREATE TABLE public.profiles (
  user_id UUID NOT NULL PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  username TEXT UNIQUE,
  role TEXT NOT NULL DEFAULT 'driver' CHECK (role IN ('admin', 'driver')),
  full_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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

CREATE TABLE public.drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  full_name TEXT,
  access_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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

-- PASSO 6: Criar índices
CREATE INDEX idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX idx_profiles_username ON public.profiles(username);
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_drivers_user_id ON public.drivers(user_id);
CREATE INDEX idx_shifts_driver_id ON public.shifts(driver_id);
CREATE INDEX idx_shifts_vehicle_id ON public.shifts(vehicle_id);
CREATE INDEX idx_shifts_date ON public.shifts(shift_date);
CREATE INDEX idx_shift_reports_shift_id ON public.shift_reports(shift_id);
CREATE INDEX idx_shift_reports_driver_id ON public.shift_reports(driver_id);

-- PASSO 7: Ativar RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_reports ENABLE ROW LEVEL SECURITY;

-- PASSO 8: Criar função de trigger para novos utilizadores
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, role)
  VALUES (new.id, new.email, 'driver')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- PASSO 9: Criar trigger para novos utilizadores
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- PASSO 10: Criar função helper para get_email_by_username
CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT email FROM public.profiles WHERE username = p_username LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- PASSO 11: Criar políticas RLS para profiles
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (
    auth.uid() = user_id OR 
    (SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin'
  );

CREATE POLICY "profiles_update_self" ON public.profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "profiles_insert_self" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- PASSO 12: Criar políticas RLS para vehicles
CREATE POLICY "vehicles_admin" ON public.vehicles
  FOR ALL USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin');

CREATE POLICY "vehicles_driver_select" ON public.vehicles
  FOR SELECT USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'driver');

-- PASSO 13: Criar políticas RLS para drivers
CREATE POLICY "drivers_admin" ON public.drivers
  FOR ALL USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin');

CREATE POLICY "drivers_self_select" ON public.drivers
  FOR SELECT USING (user_id = auth.uid());

-- PASSO 14: Criar políticas RLS para shifts
CREATE POLICY "shifts_admin" ON public.shifts
  FOR ALL USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin');

CREATE POLICY "shifts_driver_select" ON public.shifts
  FOR SELECT USING (
    driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

-- PASSO 15: Criar políticas RLS para shift_reports
CREATE POLICY "shift_reports_admin" ON public.shift_reports
  FOR ALL USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin');

CREATE POLICY "shift_reports_driver_select" ON public.shift_reports
  FOR SELECT USING (
    driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

-- ✅ SETUP COMPLETO!
-- Agora execute isto para criar o admin:
-- UPDATE public.profiles SET role = 'admin', username = 'admin' WHERE email = 'seu_email@example.com';
