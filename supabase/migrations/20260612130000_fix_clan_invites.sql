-- ── ARREGLO: INVITACIONES A CLANES ───────────────────────────────────
-- La política de INSERT en clan_members solo permitía auto-agregarse
-- (auth.uid() = user_id), por lo que el creador no podía invitar a
-- sus amigos (ni al crear el clan ni después). Ahora el creador del
-- clan también puede agregar miembros.

DROP POLICY IF EXISTS "Cualquier miembro puede agregarse a un clan" ON public.clan_members;

CREATE POLICY "Unirse o ser invitado por el creador"
ON public.clan_members FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id
  OR auth.uid() = (SELECT creator_id FROM public.clans WHERE id = clan_id)
);
