-- ============================================================
--  JOIN APP — Esquema de Base de Datos para Supabase (PostgreSQL)
--  Versión : 2.0.0
--  Motor   : PostgreSQL 15+
-- ============================================================

-- ── 1. PERFILES PÚBLICOS ──────────────────────────────────────
-- Vinculado a auth.users de Supabase
CREATE TABLE IF NOT EXISTS public.profiles (
  id                      UUID           NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name            VARCHAR(100)   NOT NULL,
  bio                     TEXT           NULL,
  profile_image_url       VARCHAR(500)   NULL DEFAULT NULL,
  is_verified             BOOLEAN        NOT NULL DEFAULT FALSE,

  -- Métricas calculadas
  rating                  DECIMAL(3,2)   NOT NULL DEFAULT 0.00,
  rating_count            INT            NOT NULL DEFAULT 0,
  activities_attended     INT            NOT NULL DEFAULT 0,
  activities_created      INT            NOT NULL DEFAULT 0,
  badges_received         INT            NOT NULL DEFAULT 0,

  -- Configuración de privacidad
  show_email              BOOLEAN        NOT NULL DEFAULT FALSE,
  show_phone              BOOLEAN        NOT NULL DEFAULT FALSE,
  allow_location_tracking BOOLEAN        NOT NULL DEFAULT FALSE,
  allow_notifications     BOOLEAN        NOT NULL DEFAULT TRUE,

  joined_date             DATE           NOT NULL DEFAULT CURRENT_DATE,
  last_active_at          TIMESTAMP WITH TIME ZONE NULL,
  
  -- Datos adicionales de contacto e información (sincronizados)
  email                   VARCHAR(255)   NULL,
  phone                   VARCHAR(20)    NULL,
  birth_date              DATE           NULL,
  gender                  VARCHAR(50)    NOT NULL DEFAULT 'prefer_not_to_say',
  age_visible             BOOLEAN        NOT NULL DEFAULT TRUE,
  setup_completed         BOOLEAN        NOT NULL DEFAULT FALSE,
  
  updated_at              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id)
);

COMMENT ON TABLE public.profiles IS 'Perfiles públicos de usuario vinculados con auth.users';

-- ── 2. INTERESES DE USUARIO ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_interests (
  id        SERIAL        PRIMARY KEY,
  user_id   UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tag       VARCHAR(50)   NOT NULL,
  CONSTRAINT uq_user_interest UNIQUE (user_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_interest_tag ON public.user_interests(tag);

-- ── 3. ACTIVIDADES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.activities (
  id                   UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id         UUID           NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  title                VARCHAR(150)   NOT NULL,
  description          TEXT           NOT NULL,
  category             VARCHAR(50)    NOT NULL DEFAULT 'Otro',
  cover_image_url      VARCHAR(500)   NULL DEFAULT NULL,
  location_name        VARCHAR(200)   NOT NULL,
  address              VARCHAR(300)   NULL DEFAULT NULL,
  latitude             DOUBLE PRECISION NULL DEFAULT NULL,
  longitude            DOUBLE PRECISION NULL DEFAULT NULL,
  event_datetime       TIMESTAMP WITH TIME ZONE NOT NULL,
  
  max_participants     INT            NOT NULL DEFAULT 10,
  current_participants INT            NOT NULL DEFAULT 0,
  age_range            VARCHAR(50)    NULL DEFAULT 'Libre',
  cost                 DECIMAL(10,2)  NULL DEFAULT 0.00,
  duration_minutes     INT            NULL DEFAULT 120,
  tags                 VARCHAR(255)   NULL DEFAULT NULL,
  suggestions          TEXT           NULL DEFAULT NULL,

  status               VARCHAR(50)    NOT NULL DEFAULT 'active',
  is_active            BOOLEAN        NOT NULL DEFAULT TRUE,
  created_at           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_activity_organizer ON public.activities(organizer_id);
CREATE INDEX IF NOT EXISTS idx_activity_category ON public.activities(category);
CREATE INDEX IF NOT EXISTS idx_activity_status ON public.activities(status, is_active);
CREATE INDEX IF NOT EXISTS idx_activity_event_date ON public.activities(event_datetime);

-- ── 4. SOLICITUDES DE UNIÓN ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.join_requests (
  id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id      UUID          NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id          UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message          TEXT          NULL,
  status           VARCHAR(50)   NOT NULL DEFAULT 'pending', -- pending, accepted, rejected, cancelled
  
  responded_by     UUID          NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  response_message TEXT          NULL,
  responded_at     TIMESTAMP WITH TIME ZONE NULL DEFAULT NULL,
  
  requested_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT uq_request_active UNIQUE (activity_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_request_activity ON public.join_requests(activity_id, status);
CREATE INDEX IF NOT EXISTS idx_request_user ON public.join_requests(user_id, status);

-- ── 5. PARTICIPANTES CONFIRMADOS ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.activity_participants (
  id               SERIAL        PRIMARY KEY,
  activity_id      UUID          NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id          UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  join_request_id  UUID          NULL REFERENCES public.join_requests(id) ON DELETE SET NULL,
  checked_in       BOOLEAN       NOT NULL DEFAULT FALSE,
  checkin_at       TIMESTAMP WITH TIME ZONE NULL DEFAULT NULL,
  checkin_lat      DOUBLE PRECISION NULL DEFAULT NULL,
  checkin_lng      DOUBLE PRECISION NULL DEFAULT NULL,
  joined_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT uq_participant UNIQUE (activity_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_participant_user ON public.activity_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_participant_activity ON public.activity_participants(activity_id);

-- ── 6. MENSAJES DE CHAT ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID          NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id     UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  message     TEXT          NOT NULL,
  type        VARCHAR(50)   NOT NULL DEFAULT 'text', -- text, image, system
  is_pinned   BOOLEAN       NOT NULL DEFAULT FALSE,
  is_deleted  BOOLEAN       NOT NULL DEFAULT FALSE,
  deleted_at  TIMESTAMP WITH TIME ZONE NULL DEFAULT NULL,
  sent_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_activity ON public.chat_messages(activity_id, sent_at);
CREATE INDEX IF NOT EXISTS idx_chat_user ON public.chat_messages(user_id);

-- ── 7. CONTRIBUCIONES ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contributions (
  id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id          UUID          NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  created_by_user_id   UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  title                VARCHAR(150)  NOT NULL,
  description          TEXT          NULL,
  category             VARCHAR(50)   NOT NULL DEFAULT 'other', -- food, drinks, supplies, transport, entertainment, other
  is_required          BOOLEAN       NOT NULL DEFAULT FALSE,
  assigned_to_user_id  UUID          NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  assigned_at          TIMESTAMP WITH TIME ZONE NULL DEFAULT NULL,
  created_at           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_contrib_activity ON public.contributions(activity_id);
CREATE INDEX IF NOT EXISTS idx_contrib_assigned ON public.contributions(assigned_to_user_id);

-- ── 8. FOTOS DEL EVENTO ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.event_photos (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID          NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id     UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  photo_url   VARCHAR(500)  NOT NULL,
  caption     VARCHAR(500)  NULL DEFAULT NULL,
  likes_count INT           NOT NULL DEFAULT 0,
  is_deleted  BOOLEAN       NOT NULL DEFAULT FALSE,
  deleted_at  TIMESTAMP WITH TIME ZONE NULL DEFAULT NULL,
  uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_photo_activity ON public.event_photos(activity_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_photo_user ON public.event_photos(user_id);

-- ── 9. LIKES DE FOTOS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.event_photo_likes (
  photo_id UUID   NOT NULL REFERENCES public.event_photos(id) ON DELETE CASCADE,
  user_id  UUID   NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  liked_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (photo_id, user_id)
);

-- ── 10. FEEDBACK ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.event_feedback (
  id                 UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id        UUID          NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id            UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  group_rating       DECIMAL(3,2)  NOT NULL,
  group_comment      TEXT          NULL,
  attendance_score   INT           NOT NULL,
  would_attend_again BOOLEAN       NOT NULL DEFAULT TRUE,
  submitted_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_feedback UNIQUE (activity_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_feedback_activity ON public.event_feedback(activity_id);

-- ── 11. ETIQUETAS DE FEEDBACK ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.event_feedback_tags (
  id          SERIAL        PRIMARY KEY,
  feedback_id UUID          NOT NULL REFERENCES public.event_feedback(id) ON DELETE CASCADE,
  type        VARCHAR(20)   NOT NULL, -- best, improvement
  tag         VARCHAR(100)  NOT NULL
);

-- ── 12. MEDALLAS / BADGES ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.badges (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id           UUID          NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  awarded_to_user_id    UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  awarded_by_user_id    UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  type                  VARCHAR(50)   NOT NULL, -- best_organizer, most_fun, super_reliable, etc.
  title                 VARCHAR(100)  NOT NULL,
  description           VARCHAR(300)  NULL,
  emoji                 VARCHAR(10)   NOT NULL,
  personal_message      TEXT          NULL,
  awarded_at            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_badge UNIQUE (activity_id, awarded_to_user_id, type)
);

CREATE INDEX IF NOT EXISTS idx_badge_recipient ON public.badges(awarded_to_user_id);
CREATE INDEX IF NOT EXISTS idx_badge_activity ON public.badges(activity_id);

-- ── 13. NOTIFICACIONES ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type        VARCHAR(50)   NOT NULL, -- join_request, request_accepted, etc.
  title       VARCHAR(200)  NOT NULL,
  body        TEXT          NULL,
  entity_type VARCHAR(50)   NULL,
  entity_id   UUID          NULL,
  is_read     BOOLEAN       NOT NULL DEFAULT FALSE,
  read_at     TIMESTAMP WITH TIME ZONE NULL DEFAULT NULL,
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notif_user ON public.notifications(user_id, is_read, created_at DESC);

-- ── 14. REPORTES / MODERACIÓN ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reports (
  id             SERIAL        PRIMARY KEY,
  reporter_id    UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  entity_type    VARCHAR(50)   NOT NULL, -- user, activity, message, photo
  entity_id      UUID          NOT NULL,
  reason         VARCHAR(50)   NOT NULL,
  description    TEXT          NULL,
  status         VARCHAR(50)   NOT NULL DEFAULT 'pending',
  resolved_by    UUID          NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolved_at    TIMESTAMP WITH TIME ZONE NULL DEFAULT NULL,
  created_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ── 15. AUDITORÍA ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id          BIGSERIAL     PRIMARY KEY,
  user_id     UUID          NULL DEFAULT NULL,
  action      VARCHAR(100)  NOT NULL,
  entity_type VARCHAR(50)   NULL,
  entity_id   UUID          NULL,
  ip_address  VARCHAR(45)   NULL,
  user_agent  VARCHAR(300)  NULL,
  metadata    JSONB         NULL,
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON public.audit_logs(user_id, created_at DESC);


-- ============================================================
--  VISTAS DE COMPATIBILIDAD
-- ============================================================

CREATE OR REPLACE VIEW public.v_public_profiles AS
SELECT
  p.id,
  p.display_name,
  p.bio,
  p.profile_image_url,
  p.is_verified,
  p.rating,
  p.rating_count,
  p.activities_attended,
  p.activities_created,
  p.badges_received,
  p.joined_date,
  p.last_active_at
FROM public.profiles p;

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
  a.created_at
FROM public.activities a
INNER JOIN public.profiles p ON p.id = a.organizer_id
WHERE a.is_active = TRUE
  AND a.status IN ('active', 'full');


-- ============================================================
--  TRIGGERS Y FUNCIONES EN POSTGRESQL
-- ============================================================

-- A. Auto-crear perfil en public.profiles al registrarse en auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    display_name,
    email,
    profile_image_url,
    setup_completed
  ) VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'fullName', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    COALESCE(new.raw_user_meta_data->>'avatarUrl', new.raw_user_meta_data->>'profileImageUrl', ''),
    FALSE
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- B. Trigger al aceptar/rechazar solicitudes de unión
CREATE OR REPLACE FUNCTION public.handle_join_request_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    -- Insertar en participantes
    INSERT INTO public.activity_participants (activity_id, user_id, join_request_id)
    VALUES (NEW.activity_id, NEW.user_id, NEW.id)
    ON CONFLICT DO NOTHING;

    -- Incrementar cupos en la actividad
    UPDATE public.activities
    SET current_participants = current_participants + 1,
        status = CASE WHEN current_participants + 1 >= max_participants THEN 'full' ELSE status END
    WHERE id = NEW.activity_id;

    -- Incrementar actividades asistidas en el perfil del usuario
    UPDATE public.profiles
    SET activities_attended = activities_attended + 1
    WHERE id = NEW.user_id;

  ELSIF NEW.status = 'rejected' AND OLD.status = 'accepted' THEN
    -- Eliminar de participantes
    DELETE FROM public.activity_participants
    WHERE activity_id = NEW.activity_id AND user_id = NEW.user_id;

    -- Decrementar cupos en la actividad
    UPDATE public.activities
    SET current_participants = GREATEST(current_participants - 1, 0),
        status = CASE WHEN status = 'full' THEN 'active' ELSE status END
    WHERE id = NEW.activity_id;

    -- Decrementar actividades asistidas
    UPDATE public.profiles
    SET activities_attended = GREATEST(activities_attended - 1, 0)
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_join_request_update ON public.join_requests;
CREATE TRIGGER trg_join_request_update
  AFTER UPDATE ON public.join_requests
  FOR EACH ROW EXECUTE PROCEDURE public.handle_join_request_update();


-- C. Trigger al crear una actividad para incrementar contadores
CREATE OR REPLACE FUNCTION public.handle_activity_created()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET activities_created = activities_created + 1
  WHERE id = NEW.organizer_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_activity_created ON public.activities;
CREATE TRIGGER trg_activity_created
  AFTER INSERT ON public.activities
  FOR EACH ROW EXECUTE PROCEDURE public.handle_activity_created();


-- D. Trigger para actualizar likes de fotos del evento
CREATE OR REPLACE FUNCTION public.handle_photo_like()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.event_photos
  SET likes_count = likes_count + 1
  WHERE id = NEW.photo_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_photo_like ON public.event_photo_likes;
CREATE TRIGGER trg_photo_like
  AFTER INSERT ON public.event_photo_likes
  FOR EACH ROW EXECUTE PROCEDURE public.handle_photo_like();

CREATE OR REPLACE FUNCTION public.handle_photo_unlike()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.event_photos
  SET likes_count = GREATEST(likes_count - 1, 0)
  WHERE id = OLD.photo_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_photo_unlike ON public.event_photo_likes;
CREATE TRIGGER trg_photo_unlike
  AFTER DELETE ON public.event_photo_likes
  FOR EACH ROW EXECUTE PROCEDURE public.handle_photo_unlike();


-- E. Trigger al otorgar medallas/badges
CREATE OR REPLACE FUNCTION public.handle_badge_awarded()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET badges_received = badges_received + 1
  WHERE id = NEW.awarded_to_user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_badge_awarded ON public.badges;
CREATE TRIGGER trg_badge_awarded
  AFTER INSERT ON public.badges
  FOR EACH ROW EXECUTE PROCEDURE public.handle_badge_awarded();


-- Agregar tablas chat_messages y notifications a la publicación realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.join_requests;


-- ============================================================
--  16. INICIALIZACIÓN DE BUCKETS DE ALMACENAMIENTO (STORAGE)
-- ============================================================

-- Crear los buckets si no existen en storage.buckets
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('avatars', 'avatars', true),
  ('activities', 'activities', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas para lectura pública de archivos en los buckets públicos
CREATE POLICY "Permitir lectura publica de avatares"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Permitir lectura publica de actividades"
ON storage.objects FOR SELECT
USING (bucket_id = 'activities');

-- Políticas para permitir subir archivos a usuarios autenticados o anónimos en desarrollo local
CREATE POLICY "Permitir subida a avatares"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Permitir subida a actividades"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'activities');
