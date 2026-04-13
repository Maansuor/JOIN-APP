-- ══════════════════════════════════════════════════════════════
--  patch_v1_2_0_seed_users_sessions.sql
--  Crea la tabla user_sessions y siembra usuarios de prueba
--  con contraseñas hasheadas (bcrypt via PHP)
--  Ejecutar DESPUÉS del patch_v1_1_0
-- ══════════════════════════════════════════════════════════════

USE `joinBD2026`;

-- ── Tabla de sesiones ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `user_sessions` (
    `id`         INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `user_id`    CHAR(36)        NOT NULL,
    `token`      VARCHAR(128)    NOT NULL,
    `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME        NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_token` (`token`),
    KEY `idx_user` (`user_id`),
    CONSTRAINT `fk_sess_user`
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Usuarios de prueba ───────────────────────────────────────
-- Contraseña: "Garcia"  → hash bcrypt
-- Contraseña: "Ortiz"   → hash bcrypt
-- Generados con: password_hash('Garcia', PASSWORD_BCRYPT)
-- ⚠️  Los hashes reales se generan con el siguiente PHP helper:
--     run_once:  curl http://localhost/join/api/seed.php

-- ── Insertar vía PHP (ver api/seed.php) ─────────────────────
-- O bien, si prefieres insertar directamente con SHA2 temporal:

-- Usuario Juan García (usuario: Juan, pass: Garcia)
INSERT IGNORE INTO `users`
    (`id`, `username`, `email`, `password_hash`, `full_name`, `is_active`, `created_at`)
VALUES
    ('user_juan',
     'Juan',
     'juan@join.app',
     -- IMPORTANTE: reemplazar con hash real ejecutando api/seed.php
     '$2y$10$placeholder_juan_hash_bcrypt_',
     'Juan García',
     1,
     NOW());

-- Usuario Max Ortiz (usuario: Max, pass: Ortiz)
INSERT IGNORE INTO `users`
    (`id`, `username`, `email`, `password_hash`, `full_name`, `is_active`, `created_at`)
VALUES
    ('user_max',
     'Max',
     'max@join.app',
     -- IMPORTANTE: reemplazar con hash real ejecutando api/seed.php
     '$2y$10$placeholder_max_hash_bcrypt__',
     'Max Ortiz',
     1,
     NOW());

-- ── Perfiles de usuarios de prueba ──────────────────────────
INSERT IGNORE INTO `user_profiles` (`user_id`) VALUES ('user_juan');
INSERT IGNORE INTO `user_profiles` (`user_id`) VALUES ('user_max');

-- ── Progreso de onboarding (no completado) ───────────────────
INSERT IGNORE INTO `profile_setup_progress` (`user_id`) VALUES ('user_juan');
INSERT IGNORE INTO `profile_setup_progress` (`user_id`) VALUES ('user_max');

-- ── Proveedores de auth ──────────────────────────────────────
INSERT IGNORE INTO `auth_providers` (`user_id`, `provider`, `provider_user_id`, `created_at`)
VALUES
    ('user_juan', 'email', 'juan@join.app', NOW()),
    ('user_max',  'email', 'max@join.app',  NOW());
