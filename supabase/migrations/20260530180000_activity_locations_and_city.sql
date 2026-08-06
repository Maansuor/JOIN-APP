-- Migration: Add city and separate meeting point columns to activities table
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS city VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS meeting_location_name VARCHAR(200) NULL,
  ADD COLUMN IF NOT EXISTS meeting_latitude DOUBLE PRECISION NULL,
  ADD COLUMN IF NOT EXISTS meeting_longitude DOUBLE PRECISION NULL,
  ADD COLUMN IF NOT EXISTS has_separate_meeting_point BOOLEAN DEFAULT FALSE;

-- Recreate view to include the new columns
CREATE OR REPLACE VIEW public.v_active_activities AS
SELECT
  a.id,
  a.title,
  a.description,
  a.category,
  a.cover_image_url,
  a.location_name,
  a.address,
  a.latitude,
  a.longitude,
  a.event_datetime,
  a.max_participants,
  a.current_participants,
  (a.max_participants - a.current_participants) AS remaining_spots,
  a.age_range,
  a.cost,
  a.duration_minutes,
  a.tags,
  a.status,
  a.organizer_id,
  p.display_name   AS organizer_name,
  p.profile_image_url AS organizer_image_url,
  p.rating         AS organizer_rating,
  p.is_verified    AS organizer_verified,
  a.created_at,
  -- Nuevas columnas
  a.city,
  a.meeting_location_name,
  a.meeting_latitude,
  a.meeting_longitude,
  a.has_separate_meeting_point
FROM public.activities a
INNER JOIN public.profiles p ON p.id = a.organizer_id
WHERE a.is_active = TRUE
  AND a.status IN ('active', 'full');
