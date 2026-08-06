-- ── LIMPIEZA Y CONSOLIDACIÓN DEL ESQUEMA ─────────────────────────────
-- Migración: 20260611060000_db_cleanup_and_consolidation.sql
-- 1) Consolida las políticas de Storage (había duplicadas por bucket
--    junto a las genéricas de 20260604180000_storage_rls.sql).
-- 2) Elimina vistas y tablas sin ningún consumidor en la app.

-- ══ 1. STORAGE: una sola familia de políticas ════════════════════════

-- Las políticas por bucket quedaron redundantes frente a las genéricas
DROP POLICY IF EXISTS "Permitir lectura publica de avatares" ON storage.objects;
DROP POLICY IF EXISTS "Permitir lectura publica de actividades" ON storage.objects;
DROP POLICY IF EXISTS "Permitir lectura publica de chat" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida a avatares" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida a actividades" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida a chat" ON storage.objects;

-- Recrear las genéricas incluyendo el bucket 'chat' (imágenes del chat de grupo)
DROP POLICY IF EXISTS "Inserción de objetos para autenticados" ON storage.objects;
CREATE POLICY "Inserción de objetos para autenticados"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id IN ('activities', 'avatars', 'chat'));

DROP POLICY IF EXISTS "Actualización de objetos por dueño" ON storage.objects;
CREATE POLICY "Actualización de objetos por dueño"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id IN ('activities', 'avatars', 'chat'))
WITH CHECK (owner = auth.uid());

DROP POLICY IF EXISTS "Eliminación de objetos por dueño" ON storage.objects;
CREATE POLICY "Eliminación de objetos por dueño"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id IN ('activities', 'avatars', 'chat') AND owner = auth.uid());

-- La política "Lectura pública de objetos" (SELECT USING true) se mantiene tal cual.

-- ══ 2. VISTAS SIN CONSUMIDORES ═══════════════════════════════════════
-- La app consulta las tablas directamente con embeds de PostgREST.
DROP VIEW IF EXISTS public.v_active_activities;
DROP VIEW IF EXISTS public.v_public_profiles;

-- ══ 3. TABLAS SIN LECTORES NI ESCRITORES ═════════════════════════════
-- Ningún código de la app ni trigger escribe o lee en ellas.
-- (badges y event_feedback se conservan: son el backend previsto de
--  pantallas que ya existen en la app — event recap.)
DROP TABLE IF EXISTS public.audit_logs;
DROP TABLE IF EXISTS public.reports;
