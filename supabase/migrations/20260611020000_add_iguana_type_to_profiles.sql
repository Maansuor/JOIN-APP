-- Añadir columna iguana_type para la elección de mascota compañera
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS iguana_type TEXT DEFAULT 'non_binary';
