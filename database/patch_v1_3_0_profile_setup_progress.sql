-- ══════════════════════════════════════════════════════════════
--  patch_v1_3_0_profile_setup_progress.sql
--  Crea tabla de progreso de onboarding y retro-popula
--  usuarios existentes que no tienen fila todavía.
-- ══════════════════════════════════════════════════════════════

USE `joinBD2026`;

-- 1. Crear tabla si no existe
CREATE TABLE IF NOT EXISTS `profile_setup_progress` (
    `user_id`                 CHAR(36)        NOT NULL,
    `setup_completed`         TINYINT(1)      NOT NULL DEFAULT 0,
    `location_step`           TINYINT(1)      NOT NULL DEFAULT 0,
    `birth_step`              TINYINT(1)      NOT NULL DEFAULT 0,
    `gender_step`             TINYINT(1)      NOT NULL DEFAULT 0,
    `interests_step`          TINYINT(1)      NOT NULL DEFAULT 0,
    `notifications_step`      TINYINT(1)      NOT NULL DEFAULT 0,
    `completed_at`            DATETIME                 DEFAULT NULL,
    PRIMARY KEY (`user_id`),
    CONSTRAINT `fk_psp_user`
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Insertar fila para cada usuario que aún no la tenga
INSERT IGNORE INTO `profile_setup_progress` (`user_id`, `setup_completed`)
SELECT `id`, 0 FROM `users`;

SELECT 'patch_v1_3_0 aplicado correctamente' AS status;
