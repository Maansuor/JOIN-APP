-- Extender tabla profiles con campos de gamificación, onboarding y roles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS user_role TEXT DEFAULT 'casual',
ADD COLUMN IF NOT EXISTS completed_onboarding BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS iguana_level INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS iguana_points INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS iguana_personality TEXT DEFAULT 'friendly';

-- Crear la tabla clans (Clanes)
CREATE TABLE IF NOT EXISTS public.clans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  creator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Habilitar RLS en clans
ALTER TABLE public.clans ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad para clans
CREATE POLICY "Cualquier usuario autenticado puede ver clanes" 
ON public.clans FOR SELECT TO authenticated USING (true);

CREATE POLICY "Cualquier usuario autenticado puede crear clanes" 
ON public.clans FOR INSERT TO authenticated WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "El creador del clan puede actualizarlo" 
ON public.clans FOR UPDATE TO authenticated USING (auth.uid() = creator_id);

CREATE POLICY "El creador del clan puede eliminarlo" 
ON public.clans FOR DELETE TO authenticated USING (auth.uid() = creator_id);

-- Crear la tabla clan_members (Miembros de clanes)
CREATE TABLE IF NOT EXISTS public.clan_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clan_id UUID REFERENCES public.clans(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(clan_id, user_id)
);

-- Habilitar RLS en clan_members
ALTER TABLE public.clan_members ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad para clan_members
CREATE POLICY "Cualquier usuario autenticado puede ver miembros de clanes" 
ON public.clan_members FOR SELECT TO authenticated USING (true);

CREATE POLICY "Cualquier miembro puede agregarse a un clan" 
ON public.clan_members FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Un miembro puede salir de un clan o el creador puede removerlo" 
ON public.clan_members FOR DELETE TO authenticated 
USING (
  auth.uid() = user_id OR 
  auth.uid() = (SELECT creator_id FROM public.clans WHERE id = clan_id)
);
