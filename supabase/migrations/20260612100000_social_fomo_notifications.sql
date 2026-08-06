-- ── FOMO POSITIVO: NOTIFICACIONES SOCIALES ───────────────────────────
-- Migración: 20260612100000_social_fomo_notifications.sql
-- Cuando alguien es aceptado en una actividad, se notifica al resto de
-- participantes (y al organizador) para motivar la asistencia:
--   "🎉 Max se unió al plan — ¡ya somos 5!"

CREATE OR REPLACE FUNCTION public.handle_join_accepted_fomo()
RETURNS TRIGGER AS $$
DECLARE
  v_name  TEXT;
  v_title TEXT;
  v_count INT;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    SELECT display_name INTO v_name
    FROM public.profiles WHERE id = NEW.user_id;

    -- Este trigger corre ANTES que trg_join_request_update (orden
    -- alfabético), así que current_participants aún no fue incrementado.
    SELECT title, current_participants INTO v_title, v_count
    FROM public.activities WHERE id = NEW.activity_id;

    INSERT INTO public.notifications (user_id, type, title, body, entity_type, entity_id)
    SELECT m.user_id,
           'social_join',
           '🎉 ' || COALESCE(v_name, 'Alguien') || ' se unió al plan',
           '"' || v_title || '" se pone bueno — ¡ya van ' || (v_count + 1) || '! ¿Listo para ir?',
           'activity',
           NEW.activity_id
    FROM (
      SELECT a.organizer_id AS user_id
      FROM public.activities a WHERE a.id = NEW.activity_id
      UNION
      SELECT jr.user_id
      FROM public.join_requests jr
      WHERE jr.activity_id = NEW.activity_id AND jr.status = 'accepted'
    ) m
    WHERE m.user_id <> NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_join_accepted_fomo ON public.join_requests;
CREATE TRIGGER trg_join_accepted_fomo
  AFTER UPDATE ON public.join_requests
  FOR EACH ROW EXECUTE PROCEDURE public.handle_join_accepted_fomo();
