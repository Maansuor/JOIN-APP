-- ==========================================
-- Migración: Políticas de Seguridad RLS para Storage
-- ==========================================

-- RLS is enabled by default for storage.objects in Supabase.

-- 1. Política de Lectura Pública para cualquier objeto en Storage
DROP POLICY IF EXISTS "Lectura pública de objetos" ON storage.objects;
CREATE POLICY "Lectura pública de objetos"
ON storage.objects FOR SELECT
USING (true);

-- 2. Política de Inserción para usuarios autenticados
DROP POLICY IF EXISTS "Inserción de objetos para autenticados" ON storage.objects;
CREATE POLICY "Inserción de objetos para autenticados"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id IN ('activities', 'avatars'));

-- 3. Política de Actualización para usuarios autenticados (dueños de su archivo)
DROP POLICY IF EXISTS "Actualización de objetos por dueño" ON storage.objects;
CREATE POLICY "Actualización de objetos por dueño"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id IN ('activities', 'avatars'))
WITH CHECK (owner = auth.uid());

-- 4. Política de Eliminación para usuarios autenticados (dueños de su archivo)
DROP POLICY IF EXISTS "Eliminación de objetos por dueño" ON storage.objects;
CREATE POLICY "Eliminación de objetos por dueño"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id IN ('activities', 'avatars') AND owner = auth.uid());
