<?php
// ══════════════════════════════════════════════════════════════
//  onboarding.php  — Guardar datos del flujo de onboarding
//
//  POST /api/onboarding.php?action=save_step   (intermedio)
//  POST /api/onboarding.php?action=complete    (finalizar)
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';

$action = $_GET['action'] ?? '';

match ($action) {
    'save_step' => handleSaveStep(),
    'complete'  => handleComplete(),
    default     => apiError(404, "Acción '$action' no encontrada"),
};

// ── GUARDAR PASO INTERMEDIO ───────────────────────────────────
function handleSaveStep(): void {
    $session = requireAuth();
    $body    = getBody();
    $pdo     = getDB();
    $userId  = $session['user_id'];

    $step     = $body['step']  ?? null;     // 'location','birth','gender','interests','notifications'
    $value    = $body['value'] ?? null;     // dato del paso

    if ($step === null) apiError(400, 'step requerido');

    // Asegurar que existe el registro en profile_setup_progress
    $pdo->prepare('INSERT IGNORE INTO profile_setup_progress (user_id) VALUES (?)')
        ->execute([$userId]);

    switch ($step) {
        case 'birth':
            // Guardar fecha de nacimiento en user_profiles
            if ($value) {
                $pdo->prepare('UPDATE user_profiles SET birth_date = ? WHERE user_id = ?')
                    ->execute([$value, $userId]);
                $pdo->prepare('UPDATE profile_setup_progress SET step_birth_date = 1 WHERE user_id = ?')
                    ->execute([$userId]);
            }
            break;

        case 'gender':
            // Guardar género
            if ($value) {
                $pdo->prepare('UPDATE user_profiles SET gender = ? WHERE user_id = ?')
                    ->execute([$value, $userId]);
                $pdo->prepare('UPDATE profile_setup_progress SET step_gender = 1 WHERE user_id = ?')
                    ->execute([$userId]);
            }
            break;

        case 'interests':
            // Guardar intereses (array de tags) — normalizar a lowercase
            if (is_array($value)) {
                // Crear tabla si no existe
                $pdo->exec("
                    CREATE TABLE IF NOT EXISTS user_interests (
                        user_id  VARCHAR(36) NOT NULL,
                        tag      VARCHAR(60) NOT NULL,
                        PRIMARY KEY (user_id, tag)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                ");
                $pdo->prepare('DELETE FROM user_interests WHERE user_id = ?')->execute([$userId]);
                $ins = $pdo->prepare('INSERT IGNORE INTO user_interests (user_id, tag) VALUES (?, ?)');
                foreach ($value as $tag) {
                    if (is_string($tag) && strlen(trim($tag)) > 0) {
                        $ins->execute([$userId, strtolower(trim($tag))]);
                    }
                }
                $pdo->prepare('UPDATE profile_setup_progress SET step_interests = 1 WHERE user_id = ?')
                    ->execute([$userId]);
            }
            break;

        case 'location':
            $pdo->prepare('UPDATE profile_setup_progress SET step_location = 1 WHERE user_id = ?')
                ->execute([$userId]);
            break;

        case 'notifications':
            $pdo->prepare('UPDATE profile_setup_progress SET step_notifications = 1 WHERE user_id = ?')
                ->execute([$userId]);
            break;

        default:
            apiError(400, "Paso '$step' desconocido");
    }

    apiSuccess(['saved' => true]);
}

// ── COMPLETAR ONBOARDING ──────────────────────────────────────
function handleComplete(): void {
    $session = requireAuth();
    $pdo     = getDB();
    $userId  = $session['user_id'];
    $body    = getBody();

    $birthDate   = $body['birthDate']   ?? null;
    $gender      = $body['gender']      ?? 'prefer_not_to_say';
    $interests   = $body['interests']   ?? [];
    $ageVisible  = $body['ageVisible']  ?? true;

    // 1. Asegurar tablas y registros necesarios
    try {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS user_interests (
                user_id  VARCHAR(36) NOT NULL,
                tag      VARCHAR(60) NOT NULL,
                PRIMARY KEY (user_id, tag)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
        $pdo->exec("ALTER TABLE user_profiles MODIFY birth_date DATE NULL DEFAULT NULL");
    } catch(Exception $e) {}

    // Asegurar registro en profile_setup_progress
    $pdo->prepare('INSERT IGNORE INTO profile_setup_progress (user_id) VALUES (?)')
        ->execute([$userId]);

    // Asegurar registro en user_profiles
    $checkProfile = $pdo->prepare('SELECT user_id FROM user_profiles WHERE user_id = ?');
    $checkProfile->execute([$userId]);
    if (!$checkProfile->fetch()) {
        // Crear perfil base con display_name vacío si no existe
        $pdo->prepare("
            INSERT INTO user_profiles (user_id, display_name, joined_date)
            VALUES (?, '', CURDATE())
        ")->execute([$userId]);
    }

    $pdo->beginTransaction();
    try {
        // 2. Actualizar perfil con fecha de nacimiento y género
        $pdo->prepare('
            UPDATE user_profiles
            SET birth_date = ?, gender = ?, age_visible = ?
            WHERE user_id = ?
        ')->execute([$birthDate, $gender, $ageVisible ? 1 : 0, $userId]);

        // 3. Intereses: normalizar a lowercase para consistencia con el app
        $pdo->prepare('DELETE FROM user_interests WHERE user_id = ?')->execute([$userId]);
        $ins = $pdo->prepare('INSERT IGNORE INTO user_interests (user_id, tag) VALUES (?, ?)');
        foreach ($interests as $tag) {
            if (is_string($tag) && strlen(trim($tag)) > 0) {
                $ins->execute([$userId, strtolower(trim($tag))]);
            }
        }

        // 4. Marcar setup como completado (insert or update)
        $pdo->prepare('
            INSERT INTO profile_setup_progress (user_id, setup_completed, step_location, step_birth_date, step_gender, step_interests, step_notifications, completed_at)
            VALUES (?, 1, 1, 1, 1, 1, 1, NOW())
            ON DUPLICATE KEY UPDATE 
                setup_completed   = 1,
                step_location     = 1,
                step_birth_date   = 1,
                step_gender       = 1,
                step_interests    = 1,
                step_notifications = 1,
                completed_at      = NOW()
        ')->execute([$userId]);

        $pdo->commit();
    } catch (Exception $e) {
        $pdo->rollBack();
        apiError(500, 'Error guardando onboarding: ' . $e->getMessage());
    }

    apiSuccess(['setupCompleted' => true]);
}
