-- ── CÓDIGOS DE BÚSQUEDA Y CHAT PRIVADO DE CLAN ──────────────────────
-- Migración: 20260611030000_clan_chat_and_search_code.sql

-- 1. Función para generar un código de búsqueda único de 6 dígitos con prefijo J-
CREATE OR REPLACE FUNCTION public.generate_unique_search_code()
RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  LOOP
    -- Genera un código tipo J-XXXXXX (ej: J-AF3E89)
    v_code := 'J-' || upper(substring(md5(random()::text) from 1 for 6));
    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE search_code = v_code) INTO v_exists;
    IF NOT v_exists THEN
      RETURN v_code;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 2. Añadir la columna search_code a profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS search_code VARCHAR(12) UNIQUE;

-- 3. Backfill para los usuarios existentes
DO $$
DECLARE
  r RECORD;
  v_code TEXT;
BEGIN
  FOR r IN SELECT id FROM public.profiles WHERE search_code IS NULL LOOP
    v_code := public.generate_unique_search_code();
    UPDATE public.profiles SET search_code = v_code WHERE id = r.id;
  END LOOP;
END $$;

-- 4. Actualizar trigger handle_new_user() para auto-generar search_code al registrar
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_search_code TEXT;
BEGIN
  v_search_code := public.generate_unique_search_code();

  INSERT INTO public.profiles (
    id,
    display_name,
    email,
    profile_image_url,
    setup_completed,
    search_code
  ) VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'fullName', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    COALESCE(new.raw_user_meta_data->>'avatarUrl', new.raw_user_meta_data->>'profileImageUrl', ''),
    FALSE,
    v_search_code
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Crear tabla clan_messages
CREATE TABLE IF NOT EXISTS public.clan_messages (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  clan_id     UUID          NOT NULL REFERENCES public.clans(id) ON DELETE CASCADE,
  user_id     UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message     TEXT          NOT NULL,
  type        VARCHAR(50)   NOT NULL DEFAULT 'text',
  image_url   VARCHAR(500)  NULL,
  sent_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Habilitar RLS en clan_messages
ALTER TABLE public.clan_messages ENABLE ROW LEVEL SECURITY;

-- 7. Políticas de seguridad para clan_messages
CREATE POLICY "Members can select clan messages" 
ON public.clan_messages FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.clan_members 
    WHERE clan_members.clan_id = clan_messages.clan_id 
      AND clan_members.user_id = auth.uid()
  )
);

CREATE POLICY "Members can insert clan messages" 
ON public.clan_messages FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id AND
  EXISTS (
    SELECT 1 FROM public.clan_members 
    WHERE clan_members.clan_id = clan_messages.clan_id 
      AND clan_members.user_id = auth.uid()
  )
);

CREATE POLICY "Sender can delete their clan messages" 
ON public.clan_messages FOR DELETE TO authenticated
USING (auth.uid() = user_id);

-- 8. Registrar tabla clan_messages en publicación realtime de Supabase
ALTER PUBLICATION supabase_realtime ADD TABLE public.clan_messages;
