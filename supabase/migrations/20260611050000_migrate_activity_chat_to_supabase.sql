-- ── MIGRACIÓN COMPLETA DEL CHAT DE ACTIVIDAD A SUPABASE ──────────────
-- Migración: 20260611050000_migrate_activity_chat_to_supabase.sql
-- Reemplaza la API PHP (chat.php / contributions.php + MySQL remoto).
-- Las tablas chat_messages, chat_message_images, chat_message_reactions
-- y contributions ya existen; aquí se agrega lo que faltaba.

-- 1. Columna is_edited (el esquema MySQL la tenía, el de Supabase no)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS is_edited BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Confirmaciones de lectura por mensaje
CREATE TABLE IF NOT EXISTS public.chat_message_reads (
  message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  read_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_msgread_user ON public.chat_message_reads(user_id);

-- 3. La tabla de reacciones se creó sin DEFAULT en el id; corregirlo
ALTER TABLE public.chat_message_reactions
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 4. Bucket de Storage para imágenes del chat (antes: uploads/chat en XAMPP)
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat', 'chat', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Permitir lectura publica de chat" ON storage.objects;
CREATE POLICY "Permitir lectura publica de chat"
ON storage.objects FOR SELECT
USING (bucket_id = 'chat');

DROP POLICY IF EXISTS "Permitir subida a chat" ON storage.objects;
CREATE POLICY "Permitir subida a chat"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'chat');

-- 5. Notificar a los miembros del grupo cuando llega un mensaje nuevo
--    (replica el comportamiento que tenía chat.php?action=send)
CREATE OR REPLACE FUNCTION public.handle_new_chat_message()
RETURNS TRIGGER AS $$
DECLARE
  v_sender_name TEXT;
BEGIN
  SELECT display_name INTO v_sender_name
  FROM public.profiles WHERE id = NEW.user_id;

  INSERT INTO public.notifications (user_id, type, title, body, entity_type, entity_id)
  SELECT m.user_id,
         'new_message',
         'Nuevo mensaje de ' || COALESCE(v_sender_name, 'Alguien'),
         CASE WHEN NEW.type = 'image'
              THEN '📷 Envió una imagen'
              ELSE '💬 Envió un mensaje nuevo en el grupo.' END,
         'activity',
         NEW.activity_id
  FROM (
    SELECT jr.user_id
    FROM public.join_requests jr
    WHERE jr.activity_id = NEW.activity_id AND jr.status = 'accepted'
    UNION
    SELECT a.organizer_id
    FROM public.activities a
    WHERE a.id = NEW.activity_id
  ) m
  WHERE m.user_id <> NEW.user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_new_chat_message ON public.chat_messages;
CREATE TRIGGER trg_new_chat_message
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  WHEN (NEW.type <> 'system')
  EXECUTE PROCEDURE public.handle_new_chat_message();

-- 6. RPC: marcar como leídos todos los mensajes de una actividad
--    (replica chat.php?action=mark_read)
CREATE OR REPLACE FUNCTION public.mark_chat_read(p_activity_id UUID)
RETURNS void AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sesión requerida';
  END IF;

  INSERT INTO public.chat_message_reads (message_id, user_id)
  SELECT cm.id, auth.uid()
  FROM public.chat_messages cm
  WHERE cm.activity_id = p_activity_id
    AND cm.user_id <> auth.uid()
    AND cm.is_deleted = FALSE
  ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: alternar reacción de forma atómica
--    (replica chat.php?action=react — devuelve 'added' | 'updated' | 'removed')
CREATE OR REPLACE FUNCTION public.toggle_chat_reaction(p_message_id UUID, p_reaction TEXT)
RETURNS TEXT AS $$
DECLARE
  v_existing public.chat_message_reactions%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sesión requerida';
  END IF;

  SELECT * INTO v_existing
  FROM public.chat_message_reactions
  WHERE message_id = p_message_id AND user_id = auth.uid();

  IF FOUND THEN
    IF v_existing.reaction = p_reaction THEN
      DELETE FROM public.chat_message_reactions WHERE id = v_existing.id;
      RETURN 'removed';
    ELSE
      UPDATE public.chat_message_reactions
      SET reaction = p_reaction, created_at = NOW()
      WHERE id = v_existing.id;
      RETURN 'updated';
    END IF;
  ELSE
    INSERT INTO public.chat_message_reactions (message_id, user_id, reaction)
    VALUES (p_message_id, auth.uid(), p_reaction);
    RETURN 'added';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
