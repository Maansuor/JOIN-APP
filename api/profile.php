<?php
// ══════════════════════════════════════════════════════════════
//  profile.php  — Perfil de usuario
//
//  PUT  /api/profile.php?action=update   → actualizar perfil
//  GET  /api/profile.php?action=me       → obtener datos propios
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';

$action = $_GET['action'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];

match (true) {
    $action === 'update' && $method === 'PUT'  => handleUpdate(),
    $action === 'update' && $method === 'POST' => handleUpdate(), // fallback (Dart http no tiene PUT nativo fácil)
    $action === 'me'                           => handleMe(),
    default                                    => apiError(404, "Acción '$action' no encontrada"),
};

// ── ACTUALIZAR PERFIL ─────────────────────────────────────────
function handleUpdate(): void {
    $session = requireAuth();
    $body    = getBody();
    $pdo     = getDB();
    $userId  = $session['user_id'];

    $displayName = isset($body['name'])        ? trim($body['name'])      : null;
    $bio         = isset($body['bio'])         ? trim($body['bio'])       : null;
    $phone       = isset($body['phone'])       ? trim($body['phone'])     : null;
    $birthDate   = $body['birthDate']   ?? null;
    $gender      = $body['gender']     ?? null;
    $ageVisible  = isset($body['ageVisible'])  ? (bool)$body['ageVisible'] : null;
    $interests   = $body['interests']  ?? null;
    $imageBase64 = $body['image']      ?? null; // Nueva imagen en base64

    // Construir UPDATE dinámico para user_profiles
    $fields = [];
    $params = [];

    if ($displayName !== null) { $fields[] = 'display_name = ?';    $params[] = $displayName; }
    if ($bio         !== null) { $fields[] = 'bio = ?';             $params[] = $bio; }
    if ($birthDate   !== null) { $fields[] = 'birth_date = ?';      $params[] = $birthDate; }
    if ($gender      != null)  { $fields[] = 'gender = ?';          $params[] = $gender; }
    if ($ageVisible  !== null) { $fields[] = 'age_visible = ?';     $params[] = $ageVisible ? 1 : 0; }

    // Procesar imagen si viene
    if ($imageBase64) {
        $imgData = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $imageBase64));
        if ($imgData) {
            $dir = __DIR__ . '/../assets/images/avatars/';
            if (!is_dir($dir)) mkdir($dir, 0777, true);
            $fileName = 'avatar_' . $userId . '_' . time() . '.jpg';
            file_put_contents($dir . $fileName, $imgData);
            
            // URL relativa para la DB
            $photoUrl = 'assets/images/avatars/' . $fileName;
            $fields[] = 'profile_image_url = ?';
            $params[] = $photoUrl;
        }
    }

    if (!empty($fields)) {
        $params[] = $userId;
        $pdo->prepare('UPDATE user_profiles SET ' . implode(', ', $fields) . ' WHERE user_id = ?')
            ->execute($params);
    }

    // Actualizar teléfono en tabla users
    if ($phone !== null) {
        $val = ($phone === '') ? null : $phone;
        $pdo->prepare('UPDATE users SET phone = ? WHERE id = ?')
            ->execute([$val, $userId]);
    }

    // Actualizar intereses
    if (is_array($interests)) {
        $pdo->prepare('DELETE FROM user_interests WHERE user_id = ?')->execute([$userId]);
        $ins = $pdo->prepare('INSERT IGNORE INTO user_interests (user_id, tag) VALUES (?, ?)');
        foreach ($interests as $tag) {
            if (is_string($tag) && strlen(trim($tag)) > 0) {
                $ins->execute([$userId, trim($tag)]);
            }
        }
    }

    // Devolver usuario actualizado
    $stmt = $pdo->prepare("
        SELECT u.id, u.email, u.phone,
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

    apiSuccess(['user' => _formatUserProfile($user, $pdo)]);
}

// ── ME ────────────────────────────────────────────────────────
function handleMe(): void {
    $session = requireAuth();
    $pdo     = getDB();

    $stmt = $pdo->prepare("
        SELECT u.id, u.email, u.phone,
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
    apiSuccess(['user' => _formatUserProfile($user, $pdo)]);
}

// ── Helper de formato ─────────────────────────────────────────
function _formatUserProfile(array $row, PDO $pdo): array {
    $stmt = $pdo->prepare('SELECT provider FROM auth_providers WHERE user_id = ?');
    $stmt->execute([$row['id']]);
    $providers = array_column($stmt->fetchAll(), 'provider');

    $stmt = $pdo->prepare('SELECT setup_completed FROM profile_setup_progress WHERE user_id = ?');
    $stmt->execute([$row['id']]);
    $progress = $stmt->fetch();

    $stmt = $pdo->prepare('SELECT tag FROM user_interests WHERE user_id = ?');
    $stmt->execute([$row['id']]);
    $interests = array_column($stmt->fetchAll(), 'tag');

    return [
        'id'                 => $row['id'],
        'name'               => $row['display_name'] ?? '',
        'email'              => $row['email'],
        'phone'              => $row['phone'] ?? null,
        'profileImageUrl'    => $row['profile_image_url'] ?? '',
        'bio'                => $row['bio'] ?? '',
        'rating'             => isset($row['rating'])              ? (float)$row['rating']            : 0.0,
        'activitiesAttended' => isset($row['activities_attended']) ? (int)$row['activities_attended'] : 0,
        'activitiesCreated'  => isset($row['activities_created'])  ? (int)$row['activities_created']  : 0,
        'isVerified'         => isset($row['is_verified'])         ? (bool)$row['is_verified']        : false,
        'joinedDate'         => $row['joined_date'] ?? date('Y-m-d'),
        'birthDate'          => $row['birth_date']  ?? null,
        'gender'             => $row['gender']       ?? 'prefer_not_to_say',
        'ageVisible'         => isset($row['age_visible']) ? (bool)$row['age_visible'] : true,
        'interests'          => $interests,
        'authProviders'      => $providers ?: ['email'],
        'setupCompleted'     => isset($progress['setup_completed']) ? (bool)$progress['setup_completed'] : false,
    ];
}
