<?php
// ══════════════════════════════════════════════════════════════
//  auth.php  — Endpoints de autenticación
//  Alineado al schema joinBD2026 v1.2.0
//
//  POST /api/auth.php?action=login
//  POST /api/auth.php?action=register
//  POST /api/auth.php?action=logout
//  POST /api/auth.php?action=google_auth
//  GET  /api/auth.php?action=me
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/services/EmailService.php';

$action = $_GET['action'] ?? '';

match ($action) {
    'login'              => handleLogin(),
    'register'           => handleRegister(),
    'logout'             => handleLogout(),
    'google_auth'        => handleGoogleAuth(),
    'me'                 => handleMe(),
    'request_magic_code' => handleRequestMagicCode(),
    'verify_magic_code'  => handleVerifyMagicCode(),
    default              => apiError(404, "Acción '$action' no encontrada"),
};

// ── LOGIN ─────────────────────────────────────────────────────
// Busca por email (no hay campo username en el schema real)
function handleLogin(): void {
    $body     = getBody();
    $email    = trim($body['username'] ?? $body['email'] ?? ''); // acepta ambos
    $password = trim($body['password'] ?? '');

    if (!$email || !$password) {
        apiError(400, 'Email y contraseña son obligatorios');
    }

    $pdo = getDB();

    $stmt = $pdo->prepare("
        SELECT u.id, u.email, u.password_hash, u.phone,
               p.display_name, p.profile_image_url, p.bio,
               p.rating, p.activities_attended, p.activities_created,
               p.is_verified, p.joined_date,
               p.birth_date, p.gender, p.age_visible
        FROM users u
        LEFT JOIN user_profiles p ON p.user_id = u.id
        WHERE u.email = ? AND u.is_active = 1 AND u.is_deleted = 0
        LIMIT 1
    ");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'] ?? '')) {
        apiError(401, 'Email o contraseña incorrectos');
    }

    $token = _createSession($pdo, $user['id']);

    apiSuccess([
        'token' => $token,
        'user'  => _formatUser($user, $pdo),
    ]);
}

// ── REGISTER ─────────────────────────────────────────────────
function handleRegister(): void {
    $body        = getBody();
    $displayName = trim($body['fullName'] ?? $body['displayName'] ?? '');
    $email       = trim($body['email']    ?? '');
    $password    = trim($body['password'] ?? '');

    if (!$displayName || !$email || !$password) {
        apiError(400, 'Nombre, email y contraseña son obligatorios');
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        apiError(400, 'Email inválido');
    }

    if (strlen($password) < 6) {
        apiError(400, 'La contraseña debe tener al menos 6 caracteres');
    }

    $pdo = getDB();

    // Verificar duplicado de email
    $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ? LIMIT 1');
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        apiError(409, 'Este email ya está registrado');
    }

    $userId   = _uuid();
    $passHash = password_hash($password, PASSWORD_BCRYPT);

    $pdo->beginTransaction();
    try {
        // 1. Crear usuario (solo credenciales)
        $pdo->prepare("
            INSERT INTO users (id, email, password_hash, is_active, is_deleted, created_at)
            VALUES (?, ?, ?, 1, 0, NOW())
        ")->execute([$userId, $email, $passHash]);

        // 2. Crear perfil público
        $pdo->prepare("
            INSERT INTO user_profiles (user_id, display_name, joined_date)
            VALUES (?, ?, CURDATE())
        ")->execute([$userId, $displayName]);

        // 3. Crear progreso de onboarding
        $pdo->prepare("
            INSERT INTO profile_setup_progress (user_id) VALUES (?)
        ")->execute([$userId]);

        // 4. Registrar proveedor email
        $pdo->prepare("
            INSERT INTO auth_providers (user_id, provider, provider_user_id)
            VALUES (?, 'email', ?)
        ")->execute([$userId, $email]);

        $pdo->commit();
    } catch (Exception $e) {
        $pdo->rollBack();
        apiError(500, 'Error al crear usuario: ' . $e->getMessage());
    }

    // Traer usuario recién creado
    $stmt = $pdo->prepare("
        SELECT u.id, u.email, u.password_hash, u.phone,
               p.display_name, p.profile_image_url, p.bio,
               p.rating, p.activities_attended, p.activities_created,
               p.is_verified, p.joined_date,
               p.birth_date, p.gender, p.age_visible
        FROM users u
        LEFT JOIN user_profiles p ON p.user_id = u.id
        WHERE u.id = ?
    ");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    $token = _createSession($pdo, $userId);

    apiSuccess([
        'token' => $token,
        'user'  => _formatUser($user, $pdo),
    ], 201);
}

// ── GOOGLE AUTH ──────────────────────────────────────────────
// Verifica idToken con Google (sin Firebase) y crea/recupera usuario
function handleGoogleAuth(): void {
    $body    = getBody();
    $idToken = trim($body['idToken'] ?? '');

    if (!$idToken) {
        apiError(400, 'idToken de Google es obligatorio');
    }

    // Verificar idToken con Google tokeninfo (no necesita Firebase)
    $url  = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($idToken);
    $ctx  = stream_context_create(['http' => ['timeout' => 10]]);
    $resp = @file_get_contents($url, false, $ctx);

    if ($resp === false) {
        apiError(503, 'No se pudo verificar el token de Google. Verifica la conexión.');
    }

    $payload = json_decode($resp, true);

    if (empty($payload['sub']) || empty($payload['email'])) {
        apiError(401, 'Token de Google inválido o expirado');
    }

    $googleSub  = $payload['sub'];
    $email      = $payload['email'];
    $name       = $payload['name']    ?? explode('@', $email)[0];
    $pictureUrl = $payload['picture'] ?? null;
    $emailVer   = ($payload['email_verified'] ?? '') === 'true';

    if (!$emailVer) {
        apiError(403, 'El email de Google no está verificado');
    }

    $pdo = getDB();

    // 1. Buscar si ya existe vinculación Google
    $stmt = $pdo->prepare("
        SELECT u.id FROM auth_providers ap
        JOIN users u ON u.id = ap.user_id
        WHERE ap.provider = 'google' AND ap.provider_user_id = ?
          AND u.is_active = 1 AND u.is_deleted = 0
        LIMIT 1
    ");
    $stmt->execute([$googleSub]);
    $existing = $stmt->fetch();

    if ($existing) {
        $userId = $existing['id'];
        // Actualizar foto si tiene URL de Google
        if ($pictureUrl) {
            $pdo->prepare("
                UPDATE user_profiles
                SET profile_image_url = COALESCE(NULLIF(profile_image_url,''), ?)
                WHERE user_id = ?
            ")->execute([$pictureUrl, $userId]);
        }
    } else {
        // 2. Buscar por email (vincular cuenta existente)
        $stmt = $pdo->prepare("
            SELECT id FROM users
            WHERE email = ? AND is_active = 1 AND is_deleted = 0 LIMIT 1
        ");
        $stmt->execute([$email]);
        $byEmail = $stmt->fetch();

        if ($byEmail) {
            // Vincular Google a cuenta email existente
            $userId = $byEmail['id'];
            $pdo->prepare("
                INSERT IGNORE INTO auth_providers (user_id, provider, provider_user_id)
                VALUES (?, 'google', ?)
            ")->execute([$userId, $googleSub]);

            if ($pictureUrl) {
                $pdo->prepare("
                    UPDATE user_profiles
                    SET profile_image_url = COALESCE(NULLIF(profile_image_url,''), ?)
                    WHERE user_id = ?
                ")->execute([$pictureUrl, $userId]);
            }
        } else {
            // 3. Crear nuevo usuario vía Google
            $userId = _uuid();

            $pdo->beginTransaction();
            try {
                $pdo->prepare("
                    INSERT INTO users (id, email, password_hash, email_verified, email_verified_at, is_active, is_deleted, created_at)
                    VALUES (?, ?, NULL, 1, NOW(), 1, 0, NOW())
                ")->execute([$userId, $email]);

                $pdo->prepare("
                    INSERT INTO user_profiles (user_id, display_name, profile_image_url, joined_date)
                    VALUES (?, ?, ?, CURDATE())
                ")->execute([$userId, $name, $pictureUrl]);

                $pdo->prepare("
                    INSERT INTO profile_setup_progress (user_id) VALUES (?)
                ")->execute([$userId]);

                $pdo->prepare("
                    INSERT INTO auth_providers (user_id, provider, provider_user_id)
                    VALUES (?, 'google', ?)
                ")->execute([$userId, $googleSub]);

                $pdo->commit();
            } catch (Exception $e) {
                $pdo->rollBack();
                apiError(500, 'Error creando usuario Google: ' . $e->getMessage());
            }
        }
    }

    // Retornar usuario y sesión
    $stmt = $pdo->prepare("
        SELECT u.id, u.email, u.password_hash, u.phone,
               p.display_name, p.profile_image_url, p.bio,
               p.rating, p.activities_attended, p.activities_created,
               p.is_verified, p.joined_date,
               p.birth_date, p.gender, p.age_visible
        FROM users u
        LEFT JOIN user_profiles p ON p.user_id = u.id
        WHERE u.id = ?
    ");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    $token = _createSession($pdo, $userId);

    apiSuccess([
        'token' => $token,
        'user'  => _formatUser($user, $pdo),
    ]);
}

// ── LOGOUT ───────────────────────────────────────────────────
function handleLogout(): void {
    $session = requireAuth();   // devuelve 'id' y 'user_id'
    $pdo     = getDB();

    // Revocar la sesión (conserva el registro para auditoría)
    $pdo->prepare('UPDATE user_sessions SET revoked = 1, revoked_at = NOW() WHERE id = ?')
        ->execute([$session['id']]);

    apiSuccess(['message' => 'Sesión cerrada']);
}

// ── MAGIC LINK ────────────────────────────────────────────────
// Paso 1: Generar código y "enviar" email
function handleRequestMagicCode(): void {
    $body  = getBody();
    $email = trim($body['email'] ?? '');

    if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        apiError(400, 'Email válido es obligatorio');
    }

    $pdo = getDB();

    // 1. Asegurar que la tabla exista (solo para propósitos de este ejercicio)
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS user_magic_codes (
            id VARCHAR(36) PRIMARY KEY,
            email VARCHAR(255) NOT NULL,
            code VARCHAR(6) NOT NULL,
            expires_at DATETIME NOT NULL,
            used TINYINT(1) DEFAULT 0,
            INDEX idx_email_code (email, code)
        )
    ");

    // 2. Generar código de 6 dígitos
    $code      = sprintf("%06d", mt_rand(0, 999999));
    $expiresAt = date('Y-m-d H:i:s', strtotime('+15 minutes'));
    $id        = _uuid();

    // 3. Guardar en BD (invalidar anteriores para este email)
    $pdo->prepare("UPDATE user_magic_codes SET used = 1 WHERE email = ?")->execute([$email]);
    $stmt = $pdo->prepare("
        INSERT INTO user_magic_codes (id, email, code, expires_at)
        VALUES (?, ?, ?, ?)
    ");
    $stmt->execute([$id, $email, $code, $expiresAt]);

    // 4. "Enviar" email
    $sent = _sendMagicEmail($email, $code);

    if (!$sent) {
        apiError(500, 'Error al enviar el código de acceso');
    }

    // Si detectamos localhost, devolvemos el código en la respuesta para facilitar el desarrollo
    // SIN necesidad de servidor SMTP configurado.
    $debugData = ['message' => 'Código enviado. Revisa tu bandeja de entrada.'];
    if ($_SERVER['REMOTE_ADDR'] === '127.0.0.1' || $_SERVER['REMOTE_ADDR'] === '::1' || strpos($_SERVER['HTTP_HOST'], 'localhost') !== false || $_SERVER['REMOTE_ADDR'] === '10.0.2.2') {
        $debugData['debug_code'] = $code;
    }

    apiSuccess($debugData);
}

// Paso 2: Verificar código y crear sesión
function handleVerifyMagicCode(): void {
    $body  = getBody();
    $email = trim($body['email'] ?? '');
    $code  = trim($body['code']  ?? '');

    if (!$email || !$code) {
        apiError(400, 'Email y código son obligatorios');
    }

    $pdo = getDB();

    // 1. Buscar código válido
    $stmt = $pdo->prepare("
        SELECT id FROM user_magic_codes
        WHERE email = ? AND code = ? AND used = 0 AND expires_at > NOW()
        LIMIT 1
    ");
    $stmt->execute([$email, $code]);
    $validCode = $stmt->fetch();

    if (!$validCode) {
        apiError(401, 'Código inválido o expirado');
    }

    // 2. Marcar como usado
    $pdo->prepare("UPDATE user_magic_codes SET used = 1 WHERE id = ?")
        ->execute([$validCode['id']]);

    // 3. Buscar o crear usuario
    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $userRow = $stmt->fetch();

    $userId = $userRow ? $userRow['id'] : null;

    if (!$userId) {
        // Crear nuevo usuario automáticamente si no existe (Password-less)
        $userId   = _uuid();
        $pdo->beginTransaction();
        try {
            $pdo->prepare("INSERT INTO users (id, email, is_active, created_at) VALUES (?, ?, 1, NOW())")
                ->execute([$userId, $email]);
            $pdo->prepare("INSERT INTO user_profiles (user_id, display_name, joined_date) VALUES (?, ?, CURDATE())")
                ->execute([$userId, explode('@', $email)[0]]);
            $pdo->prepare("INSERT INTO profile_setup_progress (user_id) VALUES (?)")->execute([$userId]);
            $pdo->prepare("INSERT INTO auth_providers (user_id, provider, provider_user_id) VALUES (?, 'magic_link', ?)")
                ->execute([$userId, $email]);
            $pdo->commit();
        } catch (Exception $e) {
            $pdo->rollBack();
            apiError(500, 'Error al crear usuario: ' . $e->getMessage());
        }
    }

    // 4. Crear sesión
    $stmt = $pdo->prepare("
        SELECT u.id, u.email, p.display_name, p.profile_image_url
        FROM users u
        LEFT JOIN user_profiles p ON p.user_id = u.id
        WHERE u.id = ?
    ");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    $token = _createSession($pdo, $userId);

    apiSuccess([
        'token' => $token,
        'user'  => _formatUser($user, $pdo),
    ]);
}

function _sendMagicEmail(string $email, string $code): bool {
    // Usamos el nuevo servicio profesional de correo
    return EmailService::sendMagicCode($email, $code);
}

// ── ME ────────────────────────────────────────────────────────
function handleMe(): void {
    $session = requireAuth();
    $pdo     = getDB();

    $stmt = $pdo->prepare("
        SELECT u.id, u.email, u.password_hash, u.phone,
               p.display_name, p.profile_image_url, p.bio,
               p.rating, p.activities_attended, p.activities_created,
               p.is_verified, p.joined_date,
               p.birth_date, p.gender, p.age_visible
        FROM users u
        LEFT JOIN user_profiles p ON p.user_id = u.id
        WHERE u.id = ?
    ");
    $stmt->execute([$session['user_id']]);
    $user = $stmt->fetch();

    if (!$user) apiError(404, 'Usuario no encontrado');

    apiSuccess(['user' => _formatUser($user, $pdo)]);
}

// ── Helpers privados ─────────────────────────────────────────

function _createSession(PDO $pdo, string $userId): string {
    $token     = bin2hex(random_bytes(32));   // 64 chars hex — se guarda en claro
    $sessionId = _uuid();
    $expiresAt = date('Y-m-d H:i:s', strtotime('+30 days'));

    $pdo->prepare("
        INSERT INTO user_sessions
            (id, user_id, token_hash, expires_at)
        VALUES
            (?, ?, ?, ?)
    ")->execute([$sessionId, $userId, $token, $expiresAt]);

    return $token;
}

function _formatUser(array $row, PDO $pdo): array {
    // Proveedores de auth
    $stmt = $pdo->prepare('SELECT provider FROM auth_providers WHERE user_id = ?');
    $stmt->execute([$row['id']]);
    $providers = array_column($stmt->fetchAll(), 'provider');

    // Progreso de onboarding
    $stmt = $pdo->prepare('SELECT setup_completed FROM profile_setup_progress WHERE user_id = ?');
    $stmt->execute([$row['id']]);
    $progress = $stmt->fetch();

    // Intereses (tabla user_interests con campo tag directo)
    $stmt = $pdo->prepare('SELECT tag FROM user_interests WHERE user_id = ?');
    $stmt->execute([$row['id']]);
    $interests = array_column($stmt->fetchAll(), 'tag');

    return [
        'id'              => $row['id'],
        'name'            => $row['display_name'] ?? '',
        'email'           => $row['email'],
        'phone'           => $row['phone'] ?? null,
        'profileImageUrl' => $row['profile_image_url'] ?? '',
        'bio'             => $row['bio'] ?? '',
        'rating'          => isset($row['rating'])              ? (float)$row['rating']              : 0.0,
        'activitiesAttended' => isset($row['activities_attended']) ? (int)$row['activities_attended']   : 0,
        'activitiesCreated'  => isset($row['activities_created'])  ? (int)$row['activities_created']    : 0,
        'isVerified'      => isset($row['is_verified'])         ? (bool)$row['is_verified']          : false,
        'joinedDate'      => $row['joined_date'] ?? date('Y-m-d'),
        'birthDate'       => $row['birth_date']  ?? null,
        'gender'          => $row['gender']       ?? 'prefer_not_to_say',
        'ageVisible'      => isset($row['age_visible']) ? (bool)$row['age_visible'] : true,
        'interests'       => $interests,
        'authProviders'   => $providers ?: ['email'],
        'setupCompleted'  => isset($progress['setup_completed']) ? (bool)$progress['setup_completed'] : false,
    ];
}

function _uuid(): string {
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}
