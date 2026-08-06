-- ══════════════════════════════════════════════════════════════════════
--  Activar Row Level Security en todas las tablas de datos
--  Migración: 20260806120000_enable_rls_on_all_tables.sql
--
--  Hasta ahora sólo las 4 tablas de clanes tenían RLS. Las otras 16 estaban
--  abiertas: con la anon key —que viaja dentro del APK y por tanto es
--  pública— cualquiera podía leer todos los perfiles (teléfono, fecha de
--  nacimiento, email), leer los chats de cualquier grupo y borrar actividades
--  ajenas. Esta migración cierra ese hueco.
--
--  Los 13 triggers y RPC del esquema son SECURITY DEFINER, así que siguen
--  funcionando por encima de RLS: notificaciones, alta de participantes,
--  marcado de lectura y reacciones no requieren políticas de escritura.
-- ══════════════════════════════════════════════════════════════════════


-- ══ 1. FUNCIONES AUXILIARES ══════════════════════════════════════════
-- SECURITY DEFINER a propósito: las usan las políticas y deben poder
-- consultar las tablas sin volver a pasar por RLS (evita recursión).

-- ¿El usuario organiza la actividad?
CREATE OR REPLACE FUNCTION public.is_activity_organizer(p_activity_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.activities a
     WHERE a.id = p_activity_id AND a.organizer_id = p_user_id
  );
$$;

-- ¿El usuario pertenece a la actividad, como organizador o participante?
CREATE OR REPLACE FUNCTION public.is_activity_member(p_activity_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.activities a
     WHERE a.id = p_activity_id AND a.organizer_id = p_user_id
  ) OR EXISTS (
    SELECT 1 FROM public.activity_participants ap
     WHERE ap.activity_id = p_activity_id AND ap.user_id = p_user_id
  );
$$;

-- ¿El usuario actual comparte algún clan con el usuario indicado?
-- Necesario para la inscripción grupal: un miembro apunta a todo su clan
-- a una actividad, creando solicitudes a nombre de sus compañeros.
CREATE OR REPLACE FUNCTION public.shares_clan_with(p_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.clan_members cm_self
      JOIN public.clan_members cm_other ON cm_self.clan_id = cm_other.clan_id
     WHERE cm_self.user_id = auth.uid() AND cm_other.user_id = p_user_id
  );
$$;

-- ¿El usuario puede ver el mensaje de chat indicado?
CREATE OR REPLACE FUNCTION public.can_access_chat_message(p_message_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_messages m
     WHERE m.id = p_message_id
       AND public.is_activity_member(m.activity_id, auth.uid())
  );
$$;


-- ══ 2. PERFILES E INTERESES ══════════════════════════════════════════
-- La lectura queda abierta a usuarios autenticados porque la app necesita
-- buscar personas para invitarlas a clanes y mostrar organizadores.
-- PENDIENTE: phone / email / birth_date quedan visibles entre usuarios;
-- separarlos en una vista pública es un cambio aparte.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Perfiles visibles para autenticados" ON public.profiles;
CREATE POLICY "Perfiles visibles para autenticados"
ON public.profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Cada quien edita su perfil" ON public.profiles;
CREATE POLICY "Cada quien edita su perfil"
ON public.profiles FOR UPDATE TO authenticated
USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
-- El alta la hace el trigger handle_new_user (SECURITY DEFINER): sin política
-- de INSERT, nadie puede crear perfiles a mano.


ALTER TABLE public.user_interests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Intereses visibles para autenticados" ON public.user_interests;
CREATE POLICY "Intereses visibles para autenticados"
ON public.user_interests FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Cada quien gestiona sus intereses" ON public.user_interests;
CREATE POLICY "Cada quien gestiona sus intereses"
ON public.user_interests FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- ══ 3. ACTIVIDADES ═══════════════════════════════════════════════════

ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Actividades visibles para autenticados" ON public.activities;
CREATE POLICY "Actividades visibles para autenticados"
ON public.activities FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Crear actividades propias" ON public.activities;
CREATE POLICY "Crear actividades propias"
ON public.activities FOR INSERT TO authenticated
WITH CHECK (auth.uid() = organizer_id);

DROP POLICY IF EXISTS "El organizador edita su actividad" ON public.activities;
CREATE POLICY "El organizador edita su actividad"
ON public.activities FOR UPDATE TO authenticated
USING (auth.uid() = organizer_id) WITH CHECK (auth.uid() = organizer_id);

DROP POLICY IF EXISTS "El organizador elimina su actividad" ON public.activities;
CREATE POLICY "El organizador elimina su actividad"
ON public.activities FOR DELETE TO authenticated
USING (auth.uid() = organizer_id);


-- Participantes: la app sólo lee; las altas las hace trg_join_request_update.
ALTER TABLE public.activity_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participantes visibles para autenticados" ON public.activity_participants;
CREATE POLICY "Participantes visibles para autenticados"
ON public.activity_participants FOR SELECT TO authenticated USING (true);


-- ══ 4. SOLICITUDES DE UNIÓN ══════════════════════════════════════════

ALTER TABLE public.join_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver solicitudes propias o de mis actividades" ON public.join_requests;
CREATE POLICY "Ver solicitudes propias o de mis actividades"
ON public.join_requests FOR SELECT TO authenticated
USING (
  auth.uid() = user_id
  OR public.is_activity_organizer(activity_id, auth.uid())
);

DROP POLICY IF EXISTS "Enviar solicitud propia o de un companero de clan" ON public.join_requests;
CREATE POLICY "Enviar solicitud propia o de un companero de clan"
ON public.join_requests FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id
  OR public.shares_clan_with(user_id)
);

DROP POLICY IF EXISTS "El organizador responde las solicitudes" ON public.join_requests;
CREATE POLICY "El organizador responde las solicitudes"
ON public.join_requests FOR UPDATE TO authenticated
USING (public.is_activity_organizer(activity_id, auth.uid()))
WITH CHECK (public.is_activity_organizer(activity_id, auth.uid()));

DROP POLICY IF EXISTS "Cancelar la solicitud propia" ON public.join_requests;
CREATE POLICY "Cancelar la solicitud propia"
ON public.join_requests FOR DELETE TO authenticated
USING (
  auth.uid() = user_id
  OR public.is_activity_organizer(activity_id, auth.uid())
);


-- ══ 5. CHAT DE ACTIVIDAD ═════════════════════════════════════════════

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Leer el chat de mis actividades" ON public.chat_messages;
CREATE POLICY "Leer el chat de mis actividades"
ON public.chat_messages FOR SELECT TO authenticated
USING (public.is_activity_member(activity_id, auth.uid()));

DROP POLICY IF EXISTS "Escribir en el chat de mis actividades" ON public.chat_messages;
CREATE POLICY "Escribir en el chat de mis actividades"
ON public.chat_messages FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND public.is_activity_member(activity_id, auth.uid())
);

-- El borrado es lógico (is_deleted), por eso va como UPDATE. El organizador
-- puede moderar mensajes ajenos, igual que permite la interfaz.
DROP POLICY IF EXISTS "Editar mensajes propios o moderar como organizador" ON public.chat_messages;
CREATE POLICY "Editar mensajes propios o moderar como organizador"
ON public.chat_messages FOR UPDATE TO authenticated
USING (
  auth.uid() = user_id
  OR public.is_activity_organizer(activity_id, auth.uid())
);


ALTER TABLE public.chat_message_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver imagenes del chat de mis actividades" ON public.chat_message_images;
CREATE POLICY "Ver imagenes del chat de mis actividades"
ON public.chat_message_images FOR SELECT TO authenticated
USING (public.can_access_chat_message(message_id));

DROP POLICY IF EXISTS "Adjuntar imagenes a mis mensajes" ON public.chat_message_images;
CREATE POLICY "Adjuntar imagenes a mis mensajes"
ON public.chat_message_images FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.chat_messages m
     WHERE m.id = message_id AND m.user_id = auth.uid()
  )
);


-- Reacciones y lecturas se escriben vía RPC SECURITY DEFINER
-- (toggle_chat_reaction, mark_chat_read): sólo hace falta permitir la lectura.
ALTER TABLE public.chat_message_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver reacciones del chat de mis actividades" ON public.chat_message_reactions;
CREATE POLICY "Ver reacciones del chat de mis actividades"
ON public.chat_message_reactions FOR SELECT TO authenticated
USING (public.can_access_chat_message(message_id));


ALTER TABLE public.chat_message_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver lecturas del chat de mis actividades" ON public.chat_message_reads;
CREATE POLICY "Ver lecturas del chat de mis actividades"
ON public.chat_message_reads FOR SELECT TO authenticated
USING (public.can_access_chat_message(message_id));


-- ══ 6. APORTES ═══════════════════════════════════════════════════════
-- La lectura queda abierta: el listado de actividades incrusta
-- contributions(title) para cualquiera que esté explorando el catálogo.

ALTER TABLE public.contributions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Aportes visibles para autenticados" ON public.contributions;
CREATE POLICY "Aportes visibles para autenticados"
ON public.contributions FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Crear aportes en actividades propias" ON public.contributions;
CREATE POLICY "Crear aportes en actividades propias"
ON public.contributions FOR INSERT TO authenticated
WITH CHECK (auth.uid() = created_by_user_id);

-- Cualquier miembro puede asignarse o liberar un aporte.
DROP POLICY IF EXISTS "Los miembros gestionan los aportes" ON public.contributions;
CREATE POLICY "Los miembros gestionan los aportes"
ON public.contributions FOR UPDATE TO authenticated
USING (public.is_activity_member(activity_id, auth.uid()));

DROP POLICY IF EXISTS "El organizador elimina aportes" ON public.contributions;
CREATE POLICY "El organizador elimina aportes"
ON public.contributions FOR DELETE TO authenticated
USING (public.is_activity_organizer(activity_id, auth.uid()));


-- ══ 7. MURAL DE RECUERDOS ════════════════════════════════════════════

ALTER TABLE public.event_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver fotos de mis actividades" ON public.event_photos;
CREATE POLICY "Ver fotos de mis actividades"
ON public.event_photos FOR SELECT TO authenticated
USING (public.is_activity_member(activity_id, auth.uid()));

DROP POLICY IF EXISTS "Subir fotos a mis actividades" ON public.event_photos;
CREATE POLICY "Subir fotos a mis actividades"
ON public.event_photos FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND public.is_activity_member(activity_id, auth.uid())
);

DROP POLICY IF EXISTS "Retirar mis fotos o moderar como organizador" ON public.event_photos;
CREATE POLICY "Retirar mis fotos o moderar como organizador"
ON public.event_photos FOR UPDATE TO authenticated
USING (
  auth.uid() = user_id
  OR public.is_activity_organizer(activity_id, auth.uid())
);


-- Los contadores de likes los mantienen trg_photo_like / trg_photo_unlike.
ALTER TABLE public.event_photo_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver likes de fotos visibles" ON public.event_photo_likes;
CREATE POLICY "Ver likes de fotos visibles"
ON public.event_photo_likes FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.event_photos p
     WHERE p.id = photo_id AND public.is_activity_member(p.activity_id, auth.uid())
  )
);

DROP POLICY IF EXISTS "Dar like con mi propia cuenta" ON public.event_photo_likes;
CREATE POLICY "Dar like con mi propia cuenta"
ON public.event_photo_likes FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Quitar mi propio like" ON public.event_photo_likes;
CREATE POLICY "Quitar mi propio like"
ON public.event_photo_likes FOR DELETE TO authenticated
USING (auth.uid() = user_id);


-- ══ 8. VALORACIONES DEL EVENTO ═══════════════════════════════════════
-- Son anónimas frente al resto: sólo las ve quien las escribió.

ALTER TABLE public.event_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver mis propias valoraciones" ON public.event_feedback;
CREATE POLICY "Ver mis propias valoraciones"
ON public.event_feedback FOR SELECT TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Valorar actividades a las que asisti" ON public.event_feedback;
CREATE POLICY "Valorar actividades a las que asisti"
ON public.event_feedback FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND public.is_activity_member(activity_id, auth.uid())
);


ALTER TABLE public.event_feedback_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver las etiquetas de mis valoraciones" ON public.event_feedback_tags;
CREATE POLICY "Ver las etiquetas de mis valoraciones"
ON public.event_feedback_tags FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.event_feedback f
     WHERE f.id = feedback_id AND f.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Etiquetar mis valoraciones" ON public.event_feedback_tags;
CREATE POLICY "Etiquetar mis valoraciones"
ON public.event_feedback_tags FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.event_feedback f
     WHERE f.id = feedback_id AND f.user_id = auth.uid()
  )
);


-- ══ 9. INSIGNIAS ═════════════════════════════════════════════════════
-- Se muestran en el perfil público, así que la lectura queda abierta.

ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Insignias visibles para autenticados" ON public.badges;
CREATE POLICY "Insignias visibles para autenticados"
ON public.badges FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Otorgar insignias en nombre propio" ON public.badges;
CREATE POLICY "Otorgar insignias en nombre propio"
ON public.badges FOR INSERT TO authenticated
WITH CHECK (auth.uid() = awarded_by_user_id);


-- ══ 10. NOTIFICACIONES ═══════════════════════════════════════════════
-- Las generan los triggers SECURITY DEFINER; el cliente sólo lee y marca.

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver mis notificaciones" ON public.notifications;
CREATE POLICY "Ver mis notificaciones"
ON public.notifications FOR SELECT TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Marcar mis notificaciones como leidas" ON public.notifications;
CREATE POLICY "Marcar mis notificaciones como leidas"
ON public.notifications FOR UPDATE TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar mis notificaciones" ON public.notifications;
CREATE POLICY "Eliminar mis notificaciones"
ON public.notifications FOR DELETE TO authenticated
USING (auth.uid() = user_id);


-- ══ 11. CATÁLOGO DE BUCKETS DE STORAGE ═══════════════════════════════
-- storage.buckets tenía RLS activo y ninguna política, ni de lectura: la app
-- no podía comprobar si los buckets existían e intentaba crearlos, fallando
-- con 403 en cada arranque.

DROP POLICY IF EXISTS "Lectura del catalogo de buckets" ON storage.buckets;
CREATE POLICY "Lectura del catalogo de buckets"
ON storage.buckets FOR SELECT TO authenticated, anon USING (true);


-- ══ 12. RETIRAR PERMISOS DE ESCRITURA AL ROL ANÓNIMO ═════════════════
-- Defensa en profundidad: las políticas anteriores son TO authenticated, así
-- que anon ya no obtiene filas, pero tampoco necesita el permiso de tabla.

REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE INSERT, UPDATE, DELETE ON TABLES FROM anon;
