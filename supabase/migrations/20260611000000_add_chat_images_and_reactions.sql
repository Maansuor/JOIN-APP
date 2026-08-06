-- ============================================================
-- ADD CHAT MESSAGE IMAGES AND REACTIONS TABLES
-- ============================================================

-- ── 1. CHAT MESSAGE IMAGES ──
CREATE TABLE IF NOT EXISTS public.chat_message_images (
  id          SERIAL        PRIMARY KEY,
  message_id  UUID          NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  image_url   VARCHAR(500)  NOT NULL,
  sort_order  INT           NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_msgimg_message ON public.chat_message_images(message_id);

-- ── 2. CHAT MESSAGE REACTIONS ──
CREATE TABLE IF NOT EXISTS public.chat_message_reactions (
  id          UUID          PRIMARY KEY,
  message_id  UUID          NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  user_id     UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reaction    VARCHAR(50)   NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_user_msg_reaction UNIQUE (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_msgreact_message ON public.chat_message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_msgreact_user ON public.chat_message_reactions(user_id);
