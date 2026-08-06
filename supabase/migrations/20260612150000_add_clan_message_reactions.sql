-- ── ADICIÓN DE REACCIONES Y ESTADOS A MENSAJES DE CLANES ──────────────────
-- Migración: 20260612150000_add_clan_message_reactions.sql

-- 1. Añadir columnas de estado a clan_messages (soporte para editar, borrar, fijar)
ALTER TABLE public.clan_messages
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_edited BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE NULL;

-- 2. Crear tabla para reacciones de mensajes de clanes
CREATE TABLE IF NOT EXISTS public.clan_message_reactions (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id  UUID          NOT NULL REFERENCES public.clan_messages(id) ON DELETE CASCADE,
  user_id     UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reaction    VARCHAR(50)   NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_user_clan_msg_reaction UNIQUE (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_clan_msgreact_message ON public.clan_message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_clan_msgreact_user ON public.clan_message_reactions(user_id);

-- 3. Habilitar RLS en clan_message_reactions
ALTER TABLE public.clan_message_reactions ENABLE ROW LEVEL SECURITY;

-- 4. Políticas de seguridad para clan_message_reactions
DROP POLICY IF EXISTS "Members can select clan message reactions" ON public.clan_message_reactions;
CREATE POLICY "Members can select clan message reactions" 
ON public.clan_message_reactions FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.clan_members 
    JOIN public.clan_messages ON clan_messages.clan_id = clan_members.clan_id
    WHERE clan_members.user_id = auth.uid()
      AND clan_messages.id = clan_message_reactions.message_id
  )
);

DROP POLICY IF EXISTS "Members can insert clan message reactions" ON public.clan_message_reactions;
CREATE POLICY "Members can insert clan message reactions" 
ON public.clan_message_reactions FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id AND
  EXISTS (
    SELECT 1 FROM public.clan_members 
    JOIN public.clan_messages ON clan_messages.clan_id = clan_members.clan_id
    WHERE clan_members.user_id = auth.uid()
      AND clan_messages.id = message_id
  )
);

DROP POLICY IF EXISTS "Users can delete their own reactions" ON public.clan_message_reactions;
CREATE POLICY "Users can delete their own reactions" 
ON public.clan_message_reactions FOR DELETE TO authenticated
USING (auth.uid() = user_id);

-- 5. RPC: alternar reacción en mensajes de clanes de forma atómica
CREATE OR REPLACE FUNCTION public.toggle_clan_message_reaction(p_message_id UUID, p_reaction TEXT)
RETURNS TEXT AS $$
DECLARE
  v_existing public.clan_message_reactions%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sesión requerida';
  END IF;

  SELECT * INTO v_existing
  FROM public.clan_message_reactions
  WHERE message_id = p_message_id AND user_id = auth.uid();

  IF FOUND THEN
    IF v_existing.reaction = p_reaction THEN
      DELETE FROM public.clan_message_reactions WHERE id = v_existing.id;
      RETURN 'removed';
    ELSE
      UPDATE public.clan_message_reactions
      SET reaction = p_reaction, created_at = NOW()
      WHERE id = v_existing.id;
      RETURN 'updated';
    END IF;
  ELSE
    INSERT INTO public.clan_message_reactions (message_id, user_id, reaction)
    VALUES (p_message_id, auth.uid(), p_reaction);
    RETURN 'added';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Registrar tabla clan_message_reactions en realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.clan_message_reactions;
