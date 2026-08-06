-- ══════════════════════════════════════════════════════════════════════
--  Buscar actividades cercanas sin construir el filtro con texto
--  Migración: 20260806140000_activities_near_rpc.sql
--
--  Hasta ahora la app armaba el filtro .or() de PostgREST concatenando la
--  ciudad del usuario dentro de la cadena. Eso traía dos problemas:
--
--  1. Frágil: los nombres llegan del geocodificador como texto libre ("El
--     Tambo, Huancayo") y las comas rompen el parser de PostgREST, así que ya
--     había un parche que se saltaba la coincidencia exacta si había comas.
--
--  2. Incompleto: sólo miraba distrito y provincia, más un caso especial
--     escrito a mano para Junín. Una actividad en Jauja no aparecía para
--     alguien en El Tambo aunque el propio cálculo de cercanía de la app las
--     considera de la misma región. Eran actividades invisibles.
--
--  La función recibe los términos ya resueltos por el cliente (distrito,
--  provincia y las palabras clave de su región) como un arreglo, de modo que
--  los valores viajan como parámetros y no como texto interpolado.
-- ══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.activities_near(
  p_terms    text[] DEFAULT NULL,
  p_category text   DEFAULT NULL
)
RETURNS SETOF public.activities
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT a.*
    FROM public.activities a
   WHERE a.is_active
     AND (p_category IS NULL OR p_category = 'Todos' OR a.category = p_category)
     AND (
           -- Sin términos: no se filtra por zona.
           p_terms IS NULL
           OR cardinality(p_terms) = 0
           -- Las propias siempre se ven, estén donde estén.
           OR a.organizer_id = auth.uid()
           -- Las que no tienen ciudad no se pueden descartar por zona.
           OR a.city IS NULL
           OR a.city = ''
           OR EXISTS (
                SELECT 1
                  FROM unnest(p_terms) AS termino
                 WHERE termino <> ''
                   AND a.city ILIKE '%' || termino || '%'
              )
         )
   ORDER BY a.event_datetime;
$$;

COMMENT ON FUNCTION public.activities_near(text[], text) IS
  'Actividades activas cuya ciudad coincide con alguno de los términos de zona '
  'indicados (distrito, provincia o palabras clave de la región). Respeta RLS.';

GRANT EXECUTE ON FUNCTION public.activities_near(text[], text) TO authenticated;
