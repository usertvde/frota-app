-- PASSO 1: Criar tabelas base (sem dependências externas)

-- Tabela de perfis de utilizadores
CREATE TABLE IF NOT EXISTS public.profiles (
  user_id UUID NOT NULL PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  username TEXT UNIQUE,
  role TEXT NOT NULL DEFAULT 'driver' CHECK (role IN ('admin', 'driver')),
  full_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de veículos
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  plate TEXT UNIQUE NOT NULL,
  license_plate TEXT UNIQUE,
  year INTEGER,
  photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de colaboradores (drivers)
CREATE TABLE IF NOT EXISTS public.drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  full_name TEXT,
  access_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- PASSO 2: Criar tabelas dependentes

-- Tabela de horários
CREATE TABLE IF NOT EXISTS public.shifts (
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

-- Tabela de relatórios de turno
CREATE TABLE IF NOT EXISTS public.shift_reports (
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

-- PASSO 3: Criar índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_drivers_user_id ON public.drivers(user_id);
CREATE INDEX IF NOT EXISTS idx_shifts_driver_id ON public.shifts(driver_id);
CREATE INDEX IF NOT EXISTS idx_shifts_vehicle_id ON public.shifts(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_shifts_date ON public.shifts(shift_date);
CREATE INDEX IF NOT EXISTS idx_shift_reports_shift_id ON public.shift_reports(shift_id);
CREATE INDEX IF NOT EXISTS idx_shift_reports_driver_id ON public.shift_reports(driver_id);

-- PASSO 4: Ativar Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_reports ENABLE ROW LEVEL SECURITY;

-- PASSO 5: Definir políticas RLS

-- Políticas RLS para profiles (apenas o admin e o próprio utilizador podem ver)
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (
    auth.uid() = user_id OR 
    (SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin'
  );

DROP POLICY IF EXISTS "profiles_update_self" ON public.profiles;
CREATE POLICY "profiles_update_self" ON public.profiles
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "profiles_insert_self" ON public.profiles;
CREATE POLICY "profiles_insert_self" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Políticas RLS para vehicles (admin pode fazer tudo, drivers podem ver)
DROP POLICY IF EXISTS "vehicles_admin" ON public.vehicles;
CREATE POLICY "vehicles_admin" ON public.vehicles
  FOR ALL USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin');

DROP POLICY IF EXISTS "vehicles_driver_select" ON public.vehicles;
CREATE POLICY "vehicles_driver_select" ON public.vehicles
  FOR SELECT USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'driver');

-- Políticas RLS para drivers
DROP POLICY IF EXISTS "drivers_admin" ON public.drivers;
CREATE POLICY "drivers_admin" ON public.drivers
  FOR ALL USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin');

DROP POLICY IF EXISTS "drivers_self_select" ON public.drivers;
CREATE POLICY "drivers_self_select" ON public.drivers
  FOR SELECT USING (user_id = auth.uid());

-- Políticas RLS para shifts
DROP POLICY IF EXISTS "shifts_admin" ON public.shifts;
CREATE POLICY "shifts_admin" ON public.shifts
  FOR ALL USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin');

DROP POLICY IF EXISTS "shifts_driver_select" ON public.shifts;
CREATE POLICY "shifts_driver_select" ON public.shifts
  FOR SELECT USING (
    driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

-- Políticas RLS para shift_reports
DROP POLICY IF EXISTS "shift_reports_admin" ON public.shift_reports;
CREATE POLICY "shift_reports_admin" ON public.shift_reports
  FOR ALL USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1) = 'admin');

DROP POLICY IF EXISTS "shift_reports_driver_select" ON public.shift_reports;
CREATE POLICY "shift_reports_driver_select" ON public.shift_reports
  FOR SELECT USING (
    driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
  );

-- PASSO 6: Criar funções

-- Função para criar perfil automaticamente ao registar
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, role)
  VALUES (new.id, new.email, 'driver')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql;

-- Trigger para criar perfil quando um novo utilizador é criado
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Função para obter email por nome de utilizador
DROP FUNCTION IF EXISTS public.get_email_by_username(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username TEXT)
RETURNS TEXT
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT email FROM public.profiles WHERE username = p_username LIMIT 1);
END;
$$ LANGUAGE plpgsql;

-- INSTRUÇÕES PARA CRIAR O ADMIN:
-- 1. Vá para a autenticação do Supabase
-- 2. Crie um novo utilizador com email e senha
-- 3. Depois execute este comando SQL para torná-lo admin:
--    UPDATE profiles SET role = 'admin' WHERE email = 'seu_email_admin@example.com';
