-- ══════════════════════════════════════════════════════════════
--  patch_v1_4_0_phone_and_missing_data.sql
--  Añade columna phone a users si no existe.
--  Compatibilidad con profile.php que actualiza u.phone
-- ══════════════════════════════════════════════════════════════

-- 1. Añadir columna phone a users (si no existe)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone VARCHAR(20) NULL AFTER email;

-- 2. Índice para búsqueda rápida por teléfono (opcional)
ALTER TABLE users
  ADD INDEX IF NOT EXISTS idx_users_phone (phone);

-- 3. Asegurarse de que user_interests tiene la estructura correcta
CREATE TABLE IF NOT EXISTS user_interests (
    user_id  VARCHAR(36) NOT NULL,
    tag      VARCHAR(60) NOT NULL,
    PRIMARY KEY (user_id, tag),
    CONSTRAINT fk_ui_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Para cuentas existentes sin profile_setup_progress, insertar registro vacío
INSERT IGNORE INTO profile_setup_progress (user_id)
SELECT id FROM users WHERE id NOT IN (SELECT user_id FROM profile_setup_progress);
