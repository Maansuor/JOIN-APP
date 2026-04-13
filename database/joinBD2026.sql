-- ============================================================
--  joinBD2026 — Base de datos de la aplicación JOIN
--  Versión : 1.0.0
--  Fecha   : 2026-02-24
--  Motor   : MySQL 8.0+ (InnoDB, utf8mb4)
--
--  PRINCIPIOS DE DISEÑO
--  ─────────────────────
--  • Privacidad por diseño: datos sensibles separados de datos públicos
--  • Contraseñas hasheadas (bcrypt/argon2) NUNCA en texto plano
--  • Soft-delete en lugar de borrado físico para auditoría
--  • Geolocalización almacenada solo con consentimiento explícito
--  • Tokens de sesión con expiración y revocación
--  • Separación: datos de autenticación vs datos de perfil público
--  • Normalización 3NF con índices estratégicos para rendimiento
--  • UUID v4 como PK para evitar enumeración secuencial por atacantes
-- ============================================================

-- ── Crear y usar la base de datos ─────────────────────────────
CREATE DATABASE IF NOT EXISTS `joinBD2026`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `joinBD2026`;

-- ── Desactivar checks temporalmente para importación limpia ───
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';


-- ============================================================
--  1. USUARIOS — Datos de autenticación (privados)
--     Separados del perfil público por seguridad
-- ============================================================
CREATE TABLE IF NOT EXISTS `users` (
  `id`                 CHAR(36)       NOT NULL COMMENT 'UUID v4',
  `email`              VARCHAR(255)   NOT NULL COMMENT 'Email único, se usa para login',
  `email_verified`     TINYINT(1)     NOT NULL DEFAULT 0 COMMENT '1 = email verificado',
  `email_verified_at`  DATETIME       NULL     DEFAULT NULL,
  `phone`              VARCHAR(20)    NULL     DEFAULT NULL COMMENT 'Teléfono (opcional)',
  `phone_verified`     TINYINT(1)     NOT NULL DEFAULT 0,
  `password_hash`      VARCHAR(255)   NOT NULL COMMENT 'bcrypt/argon2 — NUNCA texto plano',
  `role`               ENUM('user','admin','moderator') NOT NULL DEFAULT 'user',
  `is_active`          TINYINT(1)     NOT NULL DEFAULT 1  COMMENT '0 = cuenta suspendida',
  `is_deleted`         TINYINT(1)     NOT NULL DEFAULT 0  COMMENT 'Soft-delete GDPR',
  `deleted_at`         DATETIME       NULL     DEFAULT NULL,
  `created_at`         DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`         DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_email`  (`email`),
  UNIQUE KEY `uq_users_phone`  (`phone`),
  KEY `idx_users_role`         (`role`),
  KEY `idx_users_is_active`    (`is_active`, `is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Credenciales de autenticación — acceso restringido';


-- ============================================================
--  2. PERFILES — Datos públicos del usuario
--     Separados de `users` para minimizar exposición
-- ============================================================
CREATE TABLE IF NOT EXISTS `user_profiles` (
  `user_id`               CHAR(36)       NOT NULL COMMENT 'FK → users.id',
  `display_name`          VARCHAR(100)   NOT NULL COMMENT 'Nombre visible en la app',
  `bio`                   TEXT           NULL COMMENT 'Descripción del usuario (máx ~500 chars)',
  `profile_image_url`     VARCHAR(500)   NULL DEFAULT NULL COMMENT 'URL de foto de perfil',
  `is_verified`           TINYINT(1)     NOT NULL DEFAULT 0 COMMENT 'Usuario verificado por el equipo',

  -- Métricas calculadas (se actualizan via triggers o jobs)
  `rating`                DECIMAL(3,2)   NOT NULL DEFAULT 0.00 COMMENT 'Promedio de rating 0.00-5.00',
  `rating_count`          INT UNSIGNED   NOT NULL DEFAULT 0    COMMENT 'Cantidad de evaluaciones recibidas',
  `activities_attended`   INT UNSIGNED   NOT NULL DEFAULT 0,
  `activities_created`    INT UNSIGNED   NOT NULL DEFAULT 0,
  `badges_received`       INT UNSIGNED   NOT NULL DEFAULT 0,

  -- Configuración de privacidad (control del usuario)
  `show_email`            TINYINT(1)     NOT NULL DEFAULT 0 COMMENT '¿Mostrar email en perfil?',
  `show_phone`            TINYINT(1)     NOT NULL DEFAULT 0 COMMENT '¿Mostrar teléfono en perfil?',
  `allow_location_tracking` TINYINT(1)  NOT NULL DEFAULT 0 COMMENT 'Consentimiento de geofencing',
  `allow_notifications`   TINYINT(1)    NOT NULL DEFAULT 1,

  `joined_date`           DATE           NOT NULL DEFAULT (CURRENT_DATE),
  `last_active_at`        DATETIME       NULL DEFAULT NULL,
  `updated_at`            DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`user_id`),
  KEY `idx_profile_rating`   (`rating` DESC),
  KEY `idx_profile_verified` (`is_verified`),

  CONSTRAINT `fk_profile_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Datos de perfil público — separados de credenciales';


-- ============================================================
--  3. INTERESES DEL USUARIO — Tabla normalizada (evita arrays)
-- ============================================================
CREATE TABLE IF NOT EXISTS `user_interests` (
  `id`      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id` CHAR(36)      NOT NULL,
  `tag`     VARCHAR(50)   NOT NULL COMMENT 'Ej: trekking, gastronomia, yoga',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_interest` (`user_id`, `tag`),
  KEY `idx_interest_tag` (`tag`),

  CONSTRAINT `fk_interest_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  4. SESIONES — Tokens de autenticación con expiración
-- ============================================================
CREATE TABLE IF NOT EXISTS `user_sessions` (
  `id`            CHAR(36)      NOT NULL COMMENT 'UUID del token de sesión',
  `user_id`       CHAR(36)      NOT NULL,
  `token_hash`    VARCHAR(255)  NOT NULL COMMENT 'SHA-256 del token — NUNCA el token en claro',
  `device_info`   VARCHAR(255)  NULL DEFAULT NULL COMMENT 'SO/dispositivo para auditoría',
  `ip_address`    VARCHAR(45)   NULL DEFAULT NULL COMMENT 'IPv4 o IPv6',
  `expires_at`    DATETIME      NOT NULL,
  `revoked`       TINYINT(1)    NOT NULL DEFAULT 0,
  `revoked_at`    DATETIME      NULL DEFAULT NULL,
  `created_at`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_session_user`    (`user_id`, `revoked`),
  KEY `idx_session_expires` (`expires_at`),

  CONSTRAINT `fk_session_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Gestión de tokens de sesión con soporte para revocación';


-- ============================================================
--  5. RECUPERACIÓN DE CONTRASEÑA
-- ============================================================
CREATE TABLE IF NOT EXISTS `password_reset_tokens` (
  `id`         INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`    CHAR(36)      NOT NULL,
  `token_hash` VARCHAR(255)  NOT NULL COMMENT 'Hash del token — NUNCA el token en claro',
  `expires_at` DATETIME      NOT NULL,
  `used`       TINYINT(1)    NOT NULL DEFAULT 0,
  `used_at`    DATETIME      NULL DEFAULT NULL,
  `created_at` DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_reset_user`    (`user_id`),
  KEY `idx_reset_expires` (`expires_at`),

  CONSTRAINT `fk_reset_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  6. ACTIVIDADES
-- ============================================================
CREATE TABLE IF NOT EXISTS `activities` (
  `id`                   CHAR(36)       NOT NULL COMMENT 'UUID v4',
  `organizer_id`         CHAR(36)       NOT NULL COMMENT 'FK → users.id',
  `title`                VARCHAR(150)   NOT NULL,
  `description`          TEXT           NOT NULL,

  -- Categoría: valores controlados
  `category`             ENUM(
                           'Deportes','Comida','Naturaleza',
                           'Chill','Juntas','Arte','Música','Otro'
                         ) NOT NULL DEFAULT 'Otro',

  -- Imágenes
  `cover_image_url`      VARCHAR(500)   NULL DEFAULT NULL,

  -- Lugar y tiempo
  `location_name`        VARCHAR(200)   NOT NULL COMMENT 'Nombre legible del lugar',
  `address`              VARCHAR(300)   NULL DEFAULT NULL,
  -- Coordenadas solo se almacenan si el organizador consiente
  `latitude`             DECIMAL(10,7)  NULL DEFAULT NULL,
  `longitude`            DECIMAL(10,7)  NULL DEFAULT NULL,
  `event_date`           DATE           NOT NULL,
  `event_time`           TIME           NOT NULL,
  `event_datetime`       DATETIME       NOT NULL COMMENT 'Desnormalizado para queries rápidos',

  -- Participantes
  `max_participants`     SMALLINT UNSIGNED NOT NULL DEFAULT 10,
  `current_participants` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `age_range`            VARCHAR(50)    NULL DEFAULT 'Libre' COMMENT 'Ej: 20-30 años',
  `distance_km`          DECIMAL(6,2)   NULL DEFAULT NULL COMMENT 'Distancia al punto central (calculada)',

  -- Estado
  `status`               ENUM('draft','active','full','cancelled','completed')
                         NOT NULL DEFAULT 'active',
  `is_active`            TINYINT(1)     NOT NULL DEFAULT 1,
  `is_deleted`           TINYINT(1)     NOT NULL DEFAULT 0,
  `deleted_at`           DATETIME       NULL DEFAULT NULL,

  `created_at`           DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`           DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_activity_organizer`  (`organizer_id`),
  KEY `idx_activity_category`   (`category`),
  KEY `idx_activity_status`     (`status`, `is_active`, `is_deleted`),
  KEY `idx_activity_event_date` (`event_datetime`),
  -- Para búsqueda geoespacial próximamente
  KEY `idx_activity_location`   (`latitude`, `longitude`),

  CONSTRAINT `fk_activity_organizer`
    FOREIGN KEY (`organizer_id`) REFERENCES `users` (`id`)
    ON DELETE RESTRICT   -- No se puede borrar un usuario con actividades activas
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  7. TAGS DE ACTIVIDAD — Normalizado (evita arrays en DB)
-- ============================================================
CREATE TABLE IF NOT EXISTS `activity_tags` (
  `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `activity_id` CHAR(36)      NOT NULL,
  `tag`         VARCHAR(50)   NOT NULL COMMENT 'Ej: trekking, parrillada, familiar',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_activity_tag` (`activity_id`, `tag`),
  KEY `idx_tag` (`tag`),

  CONSTRAINT `fk_tag_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  8. IMÁGENES DE ACTIVIDAD — Galería / cover adicionales
-- ============================================================
CREATE TABLE IF NOT EXISTS `activity_images` (
  `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `activity_id` CHAR(36)      NOT NULL,
  `image_url`   VARCHAR(500)  NOT NULL,
  `is_cover`    TINYINT(1)    NOT NULL DEFAULT 0,
  `sort_order`  TINYINT       NOT NULL DEFAULT 0,
  `uploaded_by` CHAR(36)      NULL DEFAULT NULL COMMENT 'FK → users.id',
  `uploaded_at` DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_img_activity` (`activity_id`),

  CONSTRAINT `fk_img_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  9. SOLICITUDES DE UNIÓN
-- ============================================================
CREATE TABLE IF NOT EXISTS `join_requests` (
  `id`               CHAR(36)      NOT NULL COMMENT 'UUID v4',
  `activity_id`      CHAR(36)      NOT NULL,
  `user_id`          CHAR(36)      NOT NULL COMMENT 'Quien solicita unirse',

  -- Mensaje del solicitante
  `message`          TEXT          NULL,

  -- Estado
  `status`           ENUM('pending','accepted','rejected','cancelled')
                     NOT NULL DEFAULT 'pending',

  -- Respuesta del organizador
  `responded_by`     CHAR(36)      NULL DEFAULT NULL COMMENT 'FK → users.id (organizador)',
  `response_message` TEXT          NULL,
  `responded_at`     DATETIME      NULL DEFAULT NULL,

  -- Auditoría
  `requested_at`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  -- Un usuario no puede tener dos solicitudes activas para la misma actividad
  UNIQUE KEY `uq_request_active` (`activity_id`, `user_id`),
  KEY `idx_request_activity` (`activity_id`, `status`),
  KEY `idx_request_user`     (`user_id`, `status`),

  CONSTRAINT `fk_request_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_request_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_request_responder`
    FOREIGN KEY (`responded_by`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  10. PARTICIPANTES CONFIRMADOS
--      (Se crea un registro cuando la solicitud es aceptada)
-- ============================================================
CREATE TABLE IF NOT EXISTS `activity_participants` (
  `id`               INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  `activity_id`      CHAR(36)       NOT NULL,
  `user_id`          CHAR(36)       NOT NULL,
  `join_request_id`  CHAR(36)       NULL DEFAULT NULL COMMENT 'FK → join_requests.id',

  -- Check-in con geofencing
  `checked_in`       TINYINT(1)     NOT NULL DEFAULT 0,
  `checkin_at`       DATETIME       NULL DEFAULT NULL,
  -- Coordenadas del check-in (solo si el usuario consiente)
  `checkin_lat`      DECIMAL(10,7)  NULL DEFAULT NULL,
  `checkin_lng`      DECIMAL(10,7)  NULL DEFAULT NULL,

  `joined_at`        DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_participant` (`activity_id`, `user_id`),
  KEY `idx_participant_user`     (`user_id`),
  KEY `idx_participant_activity` (`activity_id`),

  CONSTRAINT `fk_participant_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_participant_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_participant_request`
    FOREIGN KEY (`join_request_id`) REFERENCES `join_requests` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  11. MENSAJES DE CHAT
--      Cada actividad tiene su propio hilo de mensajes
-- ============================================================
CREATE TABLE IF NOT EXISTS `chat_messages` (
  `id`          CHAR(36)      NOT NULL COMMENT 'UUID v4',
  `activity_id` CHAR(36)      NOT NULL,
  `user_id`     CHAR(36)      NOT NULL COMMENT 'Quién envió el mensaje',
  `message`     TEXT          NOT NULL,
  `type`        ENUM('text','image','system') NOT NULL DEFAULT 'text',
  `is_pinned`   TINYINT(1)    NOT NULL DEFAULT 0,
  `is_deleted`  TINYINT(1)    NOT NULL DEFAULT 0 COMMENT 'Soft-delete: el usuario puede borrar su mensaje',
  `deleted_at`  DATETIME      NULL DEFAULT NULL,
  `sent_at`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_chat_activity` (`activity_id`, `sent_at`),
  KEY `idx_chat_user`     (`user_id`),
  KEY `idx_chat_pinned`   (`activity_id`, `is_pinned`),

  CONSTRAINT `fk_chat_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_chat_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE RESTRICT   -- El historial queda, solo se muestra "Mensaje eliminado"
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  12. IMÁGENES EN MENSAJES DE CHAT (relación 1:N)
-- ============================================================
CREATE TABLE IF NOT EXISTS `chat_message_images` (
  `id`         INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `message_id` CHAR(36)      NOT NULL,
  `image_url`  VARCHAR(500)  NOT NULL,
  `sort_order` TINYINT       NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  KEY `idx_msgimg_message` (`message_id`),

  CONSTRAINT `fk_msgimg_message`
    FOREIGN KEY (`message_id`) REFERENCES `chat_messages` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  13. CONTRIBUCIONES — Lista de lo que cada participante trae
-- ============================================================
CREATE TABLE IF NOT EXISTS `contributions` (
  `id`                   CHAR(36)      NOT NULL COMMENT 'UUID v4',
  `activity_id`          CHAR(36)      NOT NULL,
  `created_by_user_id`   CHAR(36)      NOT NULL COMMENT 'Organizador que creó el ítem',
  `title`                VARCHAR(150)  NOT NULL COMMENT 'Ej: Carbón, Carne, Bebidas',
  `description`          TEXT          NULL,
  `category`             ENUM('food','drinks','supplies','transport','entertainment','other')
                         NOT NULL DEFAULT 'other',
  `is_required`          TINYINT(1)    NOT NULL DEFAULT 0,
  `assigned_to_user_id`  CHAR(36)      NULL DEFAULT NULL COMMENT 'Quién se comprometió',
  `assigned_at`          DATETIME      NULL DEFAULT NULL,
  `created_at`           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_contrib_activity` (`activity_id`),
  KEY `idx_contrib_assigned` (`assigned_to_user_id`),

  CONSTRAINT `fk_contrib_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_contrib_creator`
    FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`)
    ON DELETE RESTRICT,
  CONSTRAINT `fk_contrib_assignee`
    FOREIGN KEY (`assigned_to_user_id`) REFERENCES `users` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  14. FOTOS DEL EVENTO
-- ============================================================
CREATE TABLE IF NOT EXISTS `event_photos` (
  `id`          CHAR(36)      NOT NULL COMMENT 'UUID v4',
  `activity_id` CHAR(36)      NOT NULL,
  `user_id`     CHAR(36)      NOT NULL COMMENT 'Quien subió la foto',
  `photo_url`   VARCHAR(500)  NOT NULL,
  `caption`     VARCHAR(500)  NULL DEFAULT NULL,
  `likes_count` INT UNSIGNED  NOT NULL DEFAULT 0,
  `is_deleted`  TINYINT(1)    NOT NULL DEFAULT 0,
  `deleted_at`  DATETIME      NULL DEFAULT NULL,
  `uploaded_at` DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_photo_activity` (`activity_id`, `uploaded_at`),
  KEY `idx_photo_user`     (`user_id`),

  CONSTRAINT `fk_photo_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_photo_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  15. LIKES DE FOTOS — tabla de relación normalizada
-- ============================================================
CREATE TABLE IF NOT EXISTS `event_photo_likes` (
  `photo_id` CHAR(36)   NOT NULL,
  `user_id`  CHAR(36)   NOT NULL,
  `liked_at` DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`photo_id`, `user_id`),
  KEY `idx_photolike_user` (`user_id`),

  CONSTRAINT `fk_photolike_photo`
    FOREIGN KEY (`photo_id`) REFERENCES `event_photos` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_photolike_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  16. FEEDBACK POST-EVENTO
-- ============================================================
CREATE TABLE IF NOT EXISTS `event_feedback` (
  `id`                 CHAR(36)      NOT NULL COMMENT 'UUID v4',
  `activity_id`        CHAR(36)      NOT NULL,
  `user_id`            CHAR(36)      NOT NULL,
  `group_rating`       DECIMAL(3,2)  NOT NULL COMMENT '1.0 – 5.0',
  `group_comment`      TEXT          NULL,
  `attendance_score`   TINYINT       NOT NULL COMMENT '1 – 5',
  `would_attend_again` TINYINT(1)    NOT NULL DEFAULT 1,
  `submitted_at`       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  -- Un usuario solo puede enviar un feedback por actividad
  UNIQUE KEY `uq_feedback` (`activity_id`, `user_id`),
  KEY `idx_feedback_activity` (`activity_id`),

  CONSTRAINT `fk_feedback_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_feedback_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  17. ETIQUETAS DE FEEDBACK — Lo mejor & sugerencias (1:N)
-- ============================================================
CREATE TABLE IF NOT EXISTS `event_feedback_tags` (
  `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `feedback_id` CHAR(36)      NOT NULL,
  `type`        ENUM('best','improvement') NOT NULL,
  `tag`         VARCHAR(100)  NOT NULL,

  PRIMARY KEY (`id`),
  KEY `idx_feedtag_feedback` (`feedback_id`),

  CONSTRAINT `fk_feedtag_feedback`
    FOREIGN KEY (`feedback_id`) REFERENCES `event_feedback` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  18. MEDALLAS / BADGES
-- ============================================================
CREATE TABLE IF NOT EXISTS `badges` (
  `id`                    CHAR(36)      NOT NULL COMMENT 'UUID v4',
  `activity_id`           CHAR(36)      NOT NULL,
  `awarded_to_user_id`    CHAR(36)      NOT NULL COMMENT 'Quién recibe la medalla',
  `awarded_by_user_id`    CHAR(36)      NOT NULL COMMENT 'Quién la otorga (organizador)',
  `type`                  ENUM(
                            'best_organizer','most_fun','super_reliable',
                            'best_photographer','most_spirited','helpful_contributor'
                          ) NOT NULL,
  `title`                 VARCHAR(100)  NOT NULL,
  `description`           VARCHAR(300)  NULL,
  `emoji`                 VARCHAR(10)   NOT NULL,
  `personal_message`      TEXT          NULL,
  `awarded_at`            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  -- Una medalla del mismo tipo por actividad por persona
  UNIQUE KEY `uq_badge` (`activity_id`, `awarded_to_user_id`, `type`),
  KEY `idx_badge_recipient` (`awarded_to_user_id`),
  KEY `idx_badge_activity`  (`activity_id`),

  CONSTRAINT `fk_badge_activity`
    FOREIGN KEY (`activity_id`) REFERENCES `activities` (`id`)
    ON DELETE RESTRICT,
  CONSTRAINT `fk_badge_recipient`
    FOREIGN KEY (`awarded_to_user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_badge_giver`
    FOREIGN KEY (`awarded_by_user_id`) REFERENCES `users` (`id`)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  19. NOTIFICACIONES
-- ============================================================
CREATE TABLE IF NOT EXISTS `notifications` (
  `id`          CHAR(36)      NOT NULL COMMENT 'UUID v4',
  `user_id`     CHAR(36)      NOT NULL COMMENT 'Destinatario',
  `type`        ENUM(
                  'join_request','request_accepted','request_rejected',
                  'new_message','activity_reminder','badge_received',
                  'activity_cancelled','check_in_reminder','system'
                ) NOT NULL,
  `title`       VARCHAR(200)  NOT NULL,
  `body`        TEXT          NULL,

  -- Referencia polimórfica (para navegar al recurso correcto)
  `entity_type` VARCHAR(50)   NULL COMMENT 'Ej: activity, badge, message',
  `entity_id`   CHAR(36)      NULL COMMENT 'ID del recurso relacionado',

  `is_read`     TINYINT(1)    NOT NULL DEFAULT 0,
  `read_at`     DATETIME      NULL DEFAULT NULL,
  `created_at`  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_notif_user`    (`user_id`, `is_read`, `created_at` DESC),
  KEY `idx_notif_created` (`created_at`),

  CONSTRAINT `fk_notif_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  20. REPORTES / MODERACIÓN
--      Para manejar contenido inapropiado
-- ============================================================
CREATE TABLE IF NOT EXISTS `reports` (
  `id`             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `reporter_id`    CHAR(36)      NOT NULL COMMENT 'Usuario que reporta',
  `entity_type`    ENUM('user','activity','message','photo') NOT NULL,
  `entity_id`      CHAR(36)      NOT NULL,
  `reason`         ENUM(
                     'spam','inappropriate_content','harassment',
                     'fake_info','safety_concern','other'
                   ) NOT NULL,
  `description`    TEXT          NULL,
  `status`         ENUM('pending','reviewed','resolved','dismissed')
                   NOT NULL DEFAULT 'pending',
  `resolved_by`    CHAR(36)      NULL DEFAULT NULL COMMENT 'FK → users.id (moderador)',
  `resolved_at`    DATETIME      NULL DEFAULT NULL,
  `created_at`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_report_entity`  (`entity_type`, `entity_id`),
  KEY `idx_report_status`  (`status`),
  KEY `idx_report_reporter`(`reporter_id`),

  CONSTRAINT `fk_report_reporter`
    FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Sistema de reportes para moderación de contenido';


-- ============================================================
--  21. LOG DE AUDITORÍA — Trazabilidad de acciones críticas
-- ============================================================
CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     CHAR(36)        NULL DEFAULT NULL COMMENT 'NULL = acción del sistema',
  `action`      VARCHAR(100)    NOT NULL COMMENT 'Ej: user.login, activity.delete',
  `entity_type` VARCHAR(50)     NULL,
  `entity_id`   CHAR(36)        NULL,
  `ip_address`  VARCHAR(45)     NULL,
  `user_agent`  VARCHAR(300)    NULL,
  `metadata`    JSON            NULL COMMENT 'Datos adicionales del contexto',
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_audit_user`    (`user_id`, `created_at` DESC),
  KEY `idx_audit_action`  (`action`),
  KEY `idx_audit_entity`  (`entity_type`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Log de auditoría inmutable — no tiene FK para no perder historial';


-- ============================================================
--  VISTAS ÚTILES (no exponen datos sensibles)
-- ============================================================

-- Vista de perfil público (sin email, phone, password)
CREATE OR REPLACE VIEW `v_public_profiles` AS
SELECT
  u.id,
  p.display_name,
  p.bio,
  p.profile_image_url,
  p.is_verified,
  p.rating,
  p.rating_count,
  p.activities_attended,
  p.activities_created,
  p.badges_received,
  p.joined_date,
  p.last_active_at,
  u.role
FROM `users` u
INNER JOIN `user_profiles` p ON p.user_id = u.id
WHERE u.is_active = 1 AND u.is_deleted = 0;


-- Vista de actividades activas con info del organizador
CREATE OR REPLACE VIEW `v_active_activities` AS
SELECT
  a.id,
  a.title,
  a.description,
  a.category,
  a.cover_image_url,
  a.location_name,
  a.address,
  a.latitude,
  a.longitude,
  a.event_datetime,
  a.max_participants,
  a.current_participants,
  (a.max_participants - a.current_participants) AS remaining_spots,
  a.age_range,
  a.distance_km,
  a.status,
  a.organizer_id,
  p.display_name   AS organizer_name,
  p.profile_image_url AS organizer_image_url,
  p.rating         AS organizer_rating,
  p.is_verified    AS organizer_verified,
  a.created_at
FROM `activities` a
INNER JOIN `user_profiles` p ON p.user_id = a.organizer_id
WHERE a.is_active = 1
  AND a.is_deleted = 0
  AND a.status IN ('active', 'full');


-- ============================================================
--  TRIGGERS — Mantener contadores actualizados
-- ============================================================

DELIMITER $$

-- Incrementar participantes al aceptar solicitud
CREATE TRIGGER `trg_request_accepted`
AFTER UPDATE ON `join_requests`
FOR EACH ROW
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    INSERT IGNORE INTO `activity_participants`
      (activity_id, user_id, join_request_id)
    VALUES
      (NEW.activity_id, NEW.user_id, NEW.id);

    UPDATE `activities`
    SET current_participants = current_participants + 1,
        status = IF(current_participants + 1 >= max_participants, 'full', status)
    WHERE id = NEW.activity_id;

    -- Actualizar contador del perfil
    UPDATE `user_profiles`
    SET activities_attended = activities_attended + 1
    WHERE user_id = NEW.user_id;
  END IF;

  -- Si se rechaza después de haber sido aceptado, decrementar
  IF NEW.status = 'rejected' AND OLD.status = 'accepted' THEN
    DELETE FROM `activity_participants`
    WHERE activity_id = NEW.activity_id AND user_id = NEW.user_id;

    UPDATE `activities`
    SET current_participants = GREATEST(current_participants - 1, 0),
        status = IF(status = 'full', 'active', status)
    WHERE id = NEW.activity_id;

    UPDATE `user_profiles`
    SET activities_attended = GREATEST(activities_attended - 1, 0)
    WHERE user_id = NEW.user_id;
  END IF;
END$$


-- Incrementar actividades creadas al crear una actividad
CREATE TRIGGER `trg_activity_created`
AFTER INSERT ON `activities`
FOR EACH ROW
BEGIN
  UPDATE `user_profiles`
  SET activities_created = activities_created + 1
  WHERE user_id = NEW.organizer_id;
END$$


-- Actualizar contador de likes en fotos
CREATE TRIGGER `trg_photo_liked`
AFTER INSERT ON `event_photo_likes`
FOR EACH ROW
BEGIN
  UPDATE `event_photos`
  SET likes_count = likes_count + 1
  WHERE id = NEW.photo_id;
END$$

CREATE TRIGGER `trg_photo_unliked`
AFTER DELETE ON `event_photo_likes`
FOR EACH ROW
BEGIN
  UPDATE `event_photos`
  SET likes_count = GREATEST(likes_count - 1, 0)
  WHERE id = OLD.photo_id;  -- DELETE: usar OLD (fila eliminada), no NEW
END$$


-- Actualizar contador de badges en perfil
CREATE TRIGGER `trg_badge_awarded`
AFTER INSERT ON `badges`
FOR EACH ROW
BEGIN
  UPDATE `user_profiles`
  SET badges_received = badges_received + 1
  WHERE user_id = NEW.awarded_to_user_id;
END$$

DELIMITER ;


-- ============================================================
--  RE-ACTIVAR CHECKS
-- ============================================================
SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
--  ÍNDICE DE TABLAS
-- ============================================================
-- 1.  users                  — Credenciales de acceso (privado)
-- 2.  user_profiles          — Datos públicos del perfil
-- 3.  user_interests         — Tags de intereses (normalizado)
-- 4.  user_sessions          — Tokens de sesión con expiración
-- 5.  password_reset_tokens  — Tokens de recuperación de contraseña
-- 6.  activities             — Actividades grupales
-- 7.  activity_tags          — Tags de actividades (normalizado)
-- 8.  activity_images        — Imágenes de actividades
-- 9.  join_requests          — Solicitudes de unión
-- 10. activity_participants  — Participantes confirmados + check-in
-- 11. chat_messages          — Mensajes del chat de grupo
-- 12. chat_message_images    — Imágenes dentro de mensajes
-- 13. contributions          — Lista de aportes por participante
-- 14. event_photos           — Galería de fotos del evento
-- 15. event_photo_likes      — Likes en fotos (normalizado)
-- 16. event_feedback         — Valoraciones post-evento
-- 17. event_feedback_tags    — Etiquetas de feedback (lo mejor/mejoras)
-- 18. badges                 — Medallas otorgadas entre participantes
-- 19. notifications          — Notificaciones push/in-app
-- 20. reports                — Sistema de moderación de contenido
-- 21. audit_logs             — Trazabilidad de acciones críticas
-- ============================================================
-- FIN DEL SCRIPT
