-- ══════════════════════════════════════════════════════════════
--  patch_v1_5_0_auth_providers.sql
--  Crea tabla auth_providers para OAuth (Google, Magic Link, etc.)
-- ══════════════════════════════════════════════════════════════

USE `vitalife_join`;

-- Crear tabla auth_providers
CREATE TABLE IF NOT EXISTS `auth_providers` (
  `user_id`           CHAR(36)      NOT NULL COMMENT 'FK → users.id',
  `provider`          ENUM('email','google','magic_link','apple','facebook') NOT NULL,
  `provider_user_id`  VARCHAR(255)  NOT NULL COMMENT 'ID del usuario en el proveedor (ej: Google sub, email)',
  `provider_data`     JSON          NULL DEFAULT NULL COMMENT 'Datos adicionales del proveedor',
  `linked_at`         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_used_at`      DATETIME      NULL DEFAULT NULL,

  PRIMARY KEY (`user_id`, `provider`),
  KEY `idx_provider_user_id` (`provider`, `provider_user_id`),

  CONSTRAINT `fk_auth_provider_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Proveedores de autenticación OAuth vinculados a usuarios';
