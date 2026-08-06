-- Migration: Add current_city to profiles and create trigger for new activity notifications based on location and interests
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS current_city VARCHAR(100) NULL;

-- Create trigger function for new activity notifications
CREATE OR REPLACE FUNCTION public.handle_new_activity_notification()
RETURNS TRIGGER AS $$
DECLARE
  v_organizer_name VARCHAR(100);
BEGIN
  -- 1. Fetch organizer display name
  SELECT display_name INTO v_organizer_name
  FROM public.profiles
  WHERE id = NEW.organizer_id;

  -- 2. Find matching users and insert notifications
  -- Matching rules:
  -- - User is not the organizer
  -- - User's current_city matches the activity's city
  -- - User has at least one user_interest tag that matches the activity's category or is contained in activity's tags
  INSERT INTO public.notifications (user_id, type, title, body, entity_type, entity_id)
  SELECT 
    p.id,
    'newActivity',
    'Nuevo plan cerca de ti 🌟',
    COALESCE(v_organizer_name, 'Un organizador') || ' creó el plan "' || NEW.title || '" que coincide con tus intereses en ' || COALESCE(NEW.city, '') || '.',
    'activity',
    NEW.id
  FROM public.profiles p
  WHERE p.id != NEW.organizer_id
    AND p.current_city IS NOT NULL 
    AND NEW.city IS NOT NULL
    AND LOWER(TRIM(p.current_city)) = LOWER(TRIM(NEW.city))
    AND EXISTS (
      SELECT 1 FROM public.user_interests ui
      WHERE ui.user_id = p.id
        AND (
          LOWER(NEW.category) LIKE '%' || LOWER(ui.tag) || '%'
          OR (NEW.tags IS NOT NULL AND LOWER(NEW.tags) LIKE '%' || LOWER(ui.tag) || '%')
        )
    );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS trg_new_activity_notification ON public.activities;

-- Create the trigger
CREATE TRIGGER trg_new_activity_notification
  AFTER INSERT ON public.activities
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_activity_notification();

-- Backfill profiles from auth.users if any exist without profile (highly resilient)
INSERT INTO public.profiles (id, display_name, email, setup_completed)
SELECT 
  id, 
  COALESCE(raw_user_meta_data->>'fullName', raw_user_meta_data->>'name', split_part(email, '@', 1)), 
  email, 
  false
FROM auth.users
ON CONFLICT (id) DO NOTHING;
