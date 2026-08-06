-- Trigger function for creating notifications when join requests are created or updated
CREATE OR REPLACE FUNCTION public.handle_join_request_notification()
RETURNS TRIGGER AS $$
DECLARE
  v_activity_title VARCHAR(150);
  v_organizer_id UUID;
  v_user_name VARCHAR(100);
BEGIN
  -- 1. Fetch activity title and organizer ID
  SELECT title, organizer_id INTO v_activity_title, v_organizer_id
  FROM public.activities
  WHERE id = NEW.activity_id;

  -- 2. Fetch user display name who requested
  SELECT display_name INTO v_user_name
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Case A: New request is created (status = 'pending')
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    INSERT INTO public.notifications (user_id, type, title, body, entity_type, entity_id)
    VALUES (
      v_organizer_id,
      'joinRequest',
      'Nueva solicitud de unión 🌟',
      COALESCE(v_user_name, 'Alguien') || ' quiere unirse a tu plan "' || COALESCE(v_activity_title, '') || '".',
      'activity',
      NEW.activity_id
    );

  -- Case B: Request status is updated
  ELSIF TG_OP = 'UPDATE' AND NEW.status != OLD.status THEN
    IF NEW.status = 'accepted' THEN
      INSERT INTO public.notifications (user_id, type, title, body, entity_type, entity_id)
      VALUES (
        NEW.user_id,
        'acceptedToGroup',
        '¡Fuiste aceptado! 🎉',
        'Ya formas parte del plan "' || COALESCE(v_activity_title, '') || '". Ingresa para coordinar en el chat.',
        'activity',
        NEW.activity_id
      );
    ELSIF NEW.status = 'rejected' THEN
      INSERT INTO public.notifications (user_id, type, title, body, entity_type, entity_id)
      VALUES (
        NEW.user_id,
        'joinRequest',
        'Solicitud rechazada 😔',
        'Tu solicitud para "' || COALESCE(v_activity_title, '') || '" no pudo ser aceptada. ' || COALESCE(NEW.response_message, ''),
        'activity',
        NEW.activity_id
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS trg_join_request_notification ON public.join_requests;

-- Create the trigger
CREATE TRIGGER trg_join_request_notification
  AFTER INSERT OR UPDATE ON public.join_requests
  FOR EACH ROW EXECUTE PROCEDURE public.handle_join_request_notification();
