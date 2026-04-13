-- ============================================================
--  joinBD2026 — PATCH v1.1.0
--  Autenticación OAuth + Edad + Consentimiento de datos
--  Fecha: 2026-02-24
--
--  EJECUTAR EN ORDEN sobre la BD ya existente joinBD2026
--  (No re-importa todo el schema, solo añade lo nuevo)
-- ============================================================

USE `joinBD2026`;

SET FOREIGN_KEY_CHECKS = 0;


-- ============================================================
--  PATCH 1: Añadir birth_date a user_profiles
--  ─────────────────────────────────────────────────────────
--  • Guardamos fecha de nacimiento, NO la edad directamente
--  • La edad se calcula en tiempo real (no envejece la BD)
--  • GDPR: birth_date es dato sensible, acceso restringido
-- ============================================================
ALTER TABLE `user_profiles`
  ADD COLUMN `birth_date` DATE NOT NULL
    COMMENT 'Fecha de nacimiento — edad se calcula en tiempo real'
    AFTER `display_name`,

  ADD COLUMN `gender` ENUM('male','female','non_binary','prefer_not_to_say')
    NOT NULL DEFAULT 'prefer_not_to_say'
    COMMENT 'Opcional — para filtros de actividades'
    AFTER `birth_date`,

  ADD COLUMN `age_visible` TINYINT(1) NOT NULL DEFAULT 1
    COMMENT '¿Mostrar edad en perfil público?'
    AFTER `gender`;

-- Índice para filtrar actividades por rango de edad
ALTER TABLE `user_profiles`
  ADD KEY `idx_profile_birth_date` (`birth_date`);


-- ============================================================
--  PATCH 2: Hacer password_hash nullable en users
--  (los usuarios de OAuth no tienen contraseña local)
-- ============================================================
ALTER TABLE `users`
  MODIFY COLUMN `password_hash` VARCHAR(255) NULL DEFAULT NULL
    COMMENT 'NULL para usuarios registrados con OAuth (Google/Facebook)';


-- ============================================================
--  PATCH 3: TABLA auth_providers — OAuth + social login
--  ─────────────────────────────────────────────────────────
--  Un usuario puede tener múltiples proveedores:
--  ej: mismo correo con Google Y email/password
-- ============================================================
CREATE TABLE IF NOT EXISTS `auth_providers` (
  `id`               INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`          CHAR(36)      NOT NULL COMMENT 'FK → users.id',
  `provider`         ENUM('email','google','facebook','apple')
                     NOT NULL COMMENT 'Proveedor de autenticación',
  `provider_user_id` VARCHAR(255)  NOT NULL
                     COMMENT 'ID único del usuario en el proveedor (sub de Google, etc.)',
  -- Token de acceso OAuth (cifrado AES-256 en aplicación, nunca en claro)
  `access_token_enc` TEXT          NULL
                     COMMENT 'Token de acceso cifrado AES-256 por la app — NO descifrar en DB',
  `refresh_token_enc` TEXT         NULL
                     COMMENT 'Refresh token cifrado — rotación automática',
  `token_expires_at`  DATETIME     NULL DEFAULT NULL,
  `linked_at`        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_used_at`     DATETIME      NULL DEFAULT NULL,
  `is_active`        TINYINT(1)    NOT NULL DEFAULT 1,

  PRIMARY KEY (`id`),
  -- Un proveedor no puede tener el mismo provider_user_id dos veces
  UNIQUE KEY `uq_provider_user` (`provider`, `provider_user_id`),
  -- Un usuario no puede tener dos veces el mismo proveedor
  UNIQUE KEY `uq_user_provider` (`user_id`, `provider`),
  KEY `idx_provider_user_id` (`user_id`),

  CONSTRAINT `fk_authprov_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Proveedores de autenticación vinculados a cada cuenta';


-- ============================================================
--  PATCH 4: TABLA data_consent — Consentimiento explícito GDPR
--  ─────────────────────────────────────────────────────────
--  • Registra CUÁNDO y QUÉ aceptó el usuario
--  • Cada tipo de consentimiento es una fila separada
--  • Si el usuario revoca, se guarda la fecha de revocación
--  • Los datos siguen cifrados independientemente del consentimiento
-- ============================================================
CREATE TABLE IF NOT EXISTS `data_consent` (
  `id`            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`       CHAR(36)      NOT NULL,

  -- Tipo de consentimiento
  `consent_type`  ENUM(
                    'terms_of_service',      -- Términos y condiciones
                    'privacy_policy',        -- Política de privacidad
                    'data_processing',       -- Procesamiento de datos personales
                    'location_data',         -- Uso de ubicación para búsquedas
                    'interest_profiling',    -- Análisis de intereses para sugerencias
                    'push_notifications',    -- Notificaciones push
                    'chat_encryption',       -- Cifrado de mensajes E2E
                    'age_verification',      -- Confirmó ser mayor de edad
                    'photo_processing',      -- Procesamiento de fotos de perfil
                    'analytics'              -- Analytics anónimos de uso
                  ) NOT NULL,

  -- Estado actual
  `status`        ENUM('granted','denied','revoked') NOT NULL DEFAULT 'granted',

  -- Versión del documento que aceptó (para re-solicitar si cambia)
  `document_version` VARCHAR(20) NOT NULL DEFAULT '1.0'
                  COMMENT 'Versión de T&C o política que aceptó el usuario',

  -- Metadatos del consentimiento
  `ip_address`    VARCHAR(45)   NULL DEFAULT NULL COMMENT 'IP en el momento del consentimiento',
  `device_info`   VARCHAR(255)  NULL DEFAULT NULL COMMENT 'Dispositivo/OS',
  `granted_at`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revoked_at`    DATETIME      NULL DEFAULT NULL,
  `expires_at`    DATETIME      NULL DEFAULT NULL
                  COMMENT 'NULL = no expira. Algunos consentimientos pueden tener TTL',

  PRIMARY KEY (`id`),
  -- Un usuario solo puede tener un registro por tipo de consentimiento
  UNIQUE KEY `uq_consent` (`user_id`, `consent_type`),
  KEY `idx_consent_user`   (`user_id`, `status`),
  KEY `idx_consent_type`   (`consent_type`, `status`),

  CONSTRAINT `fk_consent_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro de consentimientos GDPR — trazable e inmutable por tipo';


-- ============================================================
--  PATCH 5: TABLA profile_setup_progress
--  ─────────────────────────────────────────────────────────
--  Controla qué pasos del onboarding ha completado el usuario.
--  Permite retomar el proceso si cierra la app a mitad.
-- ============================================================
CREATE TABLE IF NOT EXISTS `profile_setup_progress` (
  `user_id`              CHAR(36)     NOT NULL,

  -- Pasos completados (1 = completado, 0 = pendiente)
  `step_avatar`          TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Subió foto de perfil',
  `step_bio`             TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Escribió bio',
  `step_interests`       TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Seleccionó intereses (min 3)',
  `step_location`        TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Configuró ubicación',
  `step_age_consent`     TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Confirmó mayoría de edad',
  `step_data_consent`    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Aceptó consentimiento de datos',
  `setup_completed`      TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Onboarding completado',
  `completed_at`         DATETIME     NULL DEFAULT NULL,
  `updated_at`           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`user_id`),

  CONSTRAINT `fk_setup_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Progreso del onboarding del usuario';


-- ============================================================
--  PATCH 6: TABLA profile_photos
--  ─────────────────────────────────────────────────────────
--  Las fotos se guardan en el servidor (no en DB).
--  La DB solo guarda la URL y metadatos.
--  El campo en user_profiles.profile_image_url apunta a la
--  foto activa de esta tabla.
-- ============================================================
CREATE TABLE IF NOT EXISTS `profile_photos` (
  `id`          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`     CHAR(36)      NOT NULL,
  `photo_url`   VARCHAR(500)  NOT NULL
                COMMENT 'URL de la foto en el servidor o CDN',
  `is_active`   TINYINT(1)    NOT NULL DEFAULT 1
                COMMENT 'Solo una foto activa por usuario',
  `source`      ENUM('upload','google','facebook','apple')
                NOT NULL DEFAULT 'upload'
                COMMENT 'De dónde vino la foto',
  `uploaded_at` DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_photo_user`   (`user_id`, `is_active`),

  CONSTRAINT `fk_profphoto_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Historial de fotos de perfil del usuario';


-- ============================================================
--  PATCH 7: VISTA — Perfil con edad calculada
--  Actualiza la vista v_public_profiles para incluir edad
-- ============================================================
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
  u.role,
  -- Edad calculada en tiempo real (nunca queda desactualizada)
  TIMESTAMPDIFF(YEAR, p.birth_date, CURDATE()) AS age,
  -- Solo mostrar si el usuario lo permite
  CASE WHEN p.age_visible = 1
    THEN TIMESTAMPDIFF(YEAR, p.birth_date, CURDATE())
    ELSE NULL
  END AS age_public,
  p.gender,
  p.age_visible
FROM `users` u
INNER JOIN `user_profiles` p ON p.user_id = u.id
WHERE u.is_active = 1 AND u.is_deleted = 0;


-- ============================================================
--  PATCH 8: VISTA — Verificación de edad mínima (18 años)
--  Útil para el backend al validar registro
-- ============================================================
CREATE OR REPLACE VIEW `v_user_age_check` AS
SELECT
  u.id,
  p.display_name,
  p.birth_date,
  TIMESTAMPDIFF(YEAR, p.birth_date, CURDATE()) AS age,
  CASE
    WHEN TIMESTAMPDIFF(YEAR, p.birth_date, CURDATE()) >= 18 THEN 1
    ELSE 0
  END AS is_adult
FROM `users` u
INNER JOIN `user_profiles` p ON p.user_id = u.id;


-- ============================================================
--  TRIGGER: Al activar foto de perfil, desactivar las demás
-- ============================================================
DELIMITER $$

CREATE TRIGGER `trg_profile_photo_active`
BEFORE INSERT ON `profile_photos`
FOR EACH ROW
BEGIN
  IF NEW.is_active = 1 THEN
    UPDATE `profile_photos`
    SET is_active = 0
    WHERE user_id = NEW.user_id AND is_active = 1;
  END IF;
END$$

-- TRIGGER: Al completar todos los pasos del onboarding, marcar como completado
CREATE TRIGGER `trg_setup_completed`
BEFORE UPDATE ON `profile_setup_progress`
FOR EACH ROW
BEGIN
  IF NEW.step_avatar = 1
    AND NEW.step_bio = 1
    AND NEW.step_interests = 1
    AND NEW.step_age_consent = 1
    AND NEW.step_data_consent = 1
    AND NEW.setup_completed = 0
  THEN
    SET NEW.setup_completed = 1;
    SET NEW.completed_at = NOW();
  END IF;
END$$

DELIMITER ;



-- ============================================================
--  PATCH 9: TABLA device_push_tokens
--  ─────────────────────────────────────────────────────────
--  Almacena los tokens FCM (Android) / APNs (iOS) de cada
--  dispositivo del usuario para enviar notificaciones push.
--  Un usuario puede tener varios dispositivos registrados.
-- ============================================================
CREATE TABLE IF NOT EXISTS `device_push_tokens` (
  `id`           INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`      CHAR(36)      NOT NULL,
  `token`        VARCHAR(512)  NOT NULL
                 COMMENT 'Token FCM (Android) o APNs (iOS)',
  `platform`     ENUM('android','ios','web') NOT NULL DEFAULT 'android',
  `device_name`  VARCHAR(150)  NULL DEFAULT NULL
                 COMMENT 'Nombre del dispositivo (ej: iPhone 15 Pro)',
  `is_active`    TINYINT(1)    NOT NULL DEFAULT 1
                 COMMENT '0 = token expirado o revocado',
  `registered_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_used_at`  DATETIME     NULL DEFAULT NULL,

  PRIMARY KEY (`id`),
  -- Un token no puede estar registrado dos veces
  UNIQUE KEY `uq_push_token` (`token`),
  KEY `idx_push_user`   (`user_id`, `is_active`),
  KEY `idx_push_platform` (`platform`, `is_active`),

  CONSTRAINT `fk_pushtoken_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tokens de notificaciones push por dispositivo';


-- ============================================================
--  PATCH 10: TABLA notification_preferences
--  ─────────────────────────────────────────────────────────
--  Control granular de qué notificaciones el usuario quiere
--  recibir. Separado de data_consent (ese es GDPR legal,
--  esto es preferencia de UX).
-- ============================================================
CREATE TABLE IF NOT EXISTS `notification_preferences` (
  `user_id`                    CHAR(36)    NOT NULL,

  -- Notificaciones de actividades como PARTICIPANTE
  `notify_request_accepted`    TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Me aceptaron en una actividad',
  `notify_request_rejected`    TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Me rechazaron en una actividad',
  `notify_activity_reminder`   TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Recordatorio 24h antes del evento',
  `notify_activity_cancelled`  TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Una actividad en la que estoy se canceló',
  `notify_new_message`         TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Nuevo mensaje en el chat del grupo',
  `notify_checkin_reminder`    TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Recordatorio de check-in al acercarse al lugar',

  -- Notificaciones de actividades como ORGANIZADOR
  `notify_new_join_request`    TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Alguien quiere unirse a mi actividad',
  `notify_participant_checkin` TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Un participante hizo check-in',

  -- Notificaciones sociales
  `notify_badge_received`      TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Recibí una medalla',
  `notify_new_feedback`        TINYINT(1)  NOT NULL DEFAULT 0
    COMMENT 'Reciví feedback de un evento',

  -- Control global
  `push_enabled`               TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Master switch — apaga TODO si es 0',
  `email_enabled`              TINYINT(1)  NOT NULL DEFAULT 1
    COMMENT 'Notificaciones por email',
  `quiet_hours_enabled`        TINYINT(1)  NOT NULL DEFAULT 0
    COMMENT 'No molestar en horario configurado',
  `quiet_hours_from`           TIME        NULL DEFAULT '22:00:00',
  `quiet_hours_until`          TIME        NULL DEFAULT '08:00:00',

  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`user_id`),

  CONSTRAINT `fk_notifpref_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Preferencias granulares de notificaciones push por usuario';


-- ============================================================
--  PATCH 11: Actualizar profile_setup_progress
--  ─────────────────────────────────────────────────────────
--  NOTA: step_location ya existe desde PATCH 5.
--  Solo añadimos los campos nuevos del flujo definitivo:
--  step_birth_date, step_gender, step_notifications
-- ============================================================
ALTER TABLE `profile_setup_progress`
  ADD COLUMN `step_birth_date`     TINYINT(1) NOT NULL DEFAULT 0
    COMMENT 'Paso 2: Ingresó fecha de nacimiento'
    AFTER `step_location`,

  ADD COLUMN `step_gender`         TINYINT(1) NOT NULL DEFAULT 0
    COMMENT 'Paso 3: Seleccionó género'
    AFTER `step_birth_date`,

  ADD COLUMN `step_notifications`  TINYINT(1) NOT NULL DEFAULT 0
    COMMENT 'Paso 5: Autorizó notificaciones push'
    AFTER `step_interests`;


-- ============================================================
--  PATCH 12: Trigger — crear preferencias por defecto al crear usuario
--  Se dispara cuando se inserta un profile_setup_progress nuevo
-- ============================================================
DELIMITER $$

CREATE TRIGGER `trg_create_notif_prefs`
AFTER INSERT ON `profile_setup_progress`
FOR EACH ROW
BEGIN
  -- Crear preferencias de notificación con valores por defecto
  INSERT IGNORE INTO `notification_preferences` (`user_id`)
  VALUES (NEW.user_id);
END$$

-- Actualizar trigger de setup completado para incluir step_notifications
DROP TRIGGER IF EXISTS `trg_setup_completed`$$

CREATE TRIGGER `trg_setup_completed`
BEFORE UPDATE ON `profile_setup_progress`
FOR EACH ROW
BEGIN
  IF NEW.step_location = 1
    AND NEW.step_birth_date = 1
    AND NEW.step_gender = 1
    AND NEW.step_interests = 1
    AND NEW.step_notifications = 1
    AND NEW.setup_completed = 0
  THEN
    SET NEW.setup_completed = 1;
    SET NEW.completed_at = NOW();
  END IF;
END$$

DELIMITER ;


SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
--  RESUMEN COMPLETO PATCH v1.1.0
--  Importar UNA SOLA VEZ sobre joinBD2026 ya existente
-- ============================================================
-- PATCH 1:  ALTER user_profiles      → +birth_date, +gender, +age_visible
-- PATCH 2:  ALTER users              → password_hash nullable (OAuth users)
-- PATCH 3:  CREATE auth_providers    → Google / Facebook / Apple / Email
-- PATCH 4:  CREATE data_consent      → Consentimientos GDPR por tipo
-- PATCH 5:  CREATE profile_setup_progress → Progreso del onboarding
-- PATCH 6:  CREATE profile_photos    → Historial de fotos de perfil
-- PATCH 7:  UPDATE v_public_profiles → Incluye edad calculada
-- PATCH 8:  CREATE v_user_age_check  → Validación mayoría de edad
-- PATCH 9:  CREATE device_push_tokens → Tokens FCM/APNs por dispositivo
-- PATCH 10: CREATE notification_preferences → Control granular de notifs
-- PATCH 11: ALTER profile_setup_progress → +step_location/birth_date/gender/notifs
-- PATCH 12: TRIGGERS actualizados
--
-- FLUJO DE ONBOARDING (orden en la app):
--   1. ¿Dónde te encuentras?  → permiso ubicación GPS/Maps
--   2. ¿Cuándo naciste?       → fecha de nacimiento (validar 18+)
--   3. ¿Cuál es tu género?    → selección opcional
--   4. ¿Cuáles son tus intereses? → min 3 tags
--   5. Notificaciones         → permiso push (FCM/APNs)
--   → Pantalla de carga/bienvenida → MainScreen
-- ============================================================
