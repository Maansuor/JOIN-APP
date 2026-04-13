<?php
// ══════════════════════════════════════════════════════════════
//  join_requests.php  — Solicitudes de unión a actividades
//  GET  /api/join_requests.php?activity_id=X   → listar por actividad
//  GET  /api/join_requests.php?user_id=X&activity_id=Y → mi solicitud
//  POST /api/join_requests.php                 → enviar solicitud
//  PUT  /api/join_requests.php?id=X            → responder (aceptar/rechazar)
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';

$method      = $_SERVER['REQUEST_METHOD'];
$id          = $_GET['id']          ?? null;
$activityId  = $_GET['activity_id'] ?? null;
$userId      = $_GET['user_id']     ?? null;

match (true) {
    $method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'my' => getMyAllRequests(),
    $method === 'GET' && $activityId && $userId => getMyRequest($activityId, $userId),
    $method === 'GET' && $activityId            => getRequestsForActivity($activityId),
    $method === 'POST'                          => submitRequest(),
    $method === 'PUT' && $id                    => respondToRequest($id),
    default => apiError(405, 'Método no permitido'),
};

// ── TODAS MIS SOLICITUDES ────────────────────────────────────
function getMyAllRequests(): void {
    $session = requireAuth();
    $pdo = getDB();
    _ensureTables($pdo);

    $stmt = $pdo->prepare("
        SELECT jr.id, jr.activity_id, jr.user_id, jr.message,
               jr.status, jr.requested_at, jr.responded_at,
               jr.responded_by, jr.response_message,
               p.display_name AS user_name,
               p.profile_image_url AS user_image,
               p.rating AS user_rating,
               p.birth_date AS user_birth_date,
               p.gender AS user_gender
        FROM join_requests jr
        JOIN user_profiles p ON p.user_id = jr.user_id
        WHERE jr.user_id = ?
        ORDER BY jr.requested_at DESC
    ");
    $stmt->execute([$session['user_id']]);
    $rows = $stmt->fetchAll();
    apiSuccess(['requests' => array_map('_fmt', $rows)]);
}

// ── LISTAR solicitudes de una actividad ──────────────────────
function getRequestsForActivity(string $activityId): void {
    requireAuth();
    $pdo  = getDB();
    _ensureTables($pdo);
    $stmt = $pdo->prepare("
        SELECT jr.id, jr.activity_id, jr.user_id, jr.message,
               jr.status, jr.requested_at, jr.responded_at,
               jr.responded_by, jr.response_message,
               p.display_name AS user_name,
               p.profile_image_url AS user_image,
               p.rating AS user_rating,
               p.birth_date AS user_birth_date,
               p.gender AS user_gender
        FROM join_requests jr
        JOIN user_profiles p ON p.user_id = jr.user_id
        WHERE jr.activity_id = ?
        ORDER BY jr.requested_at DESC
    ");
    $stmt->execute([$activityId]);
    $rows = $stmt->fetchAll();
    apiSuccess(['requests' => array_map('_fmt', $rows)]);
}

// ── MI SOLICITUD (si existe) ─────────────────────────────────
function getMyRequest(string $activityId, string $userId): void {
    $pdo  = getDB();
    _ensureTables($pdo);
    $stmt = $pdo->prepare("
        SELECT jr.id, jr.activity_id, jr.user_id, jr.message,
               jr.status, jr.requested_at, jr.responded_at,
               jr.responded_by, jr.response_message,
               p.display_name AS user_name,
               p.profile_image_url AS user_image,
               p.rating AS user_rating,
               p.birth_date AS user_birth_date,
               p.gender AS user_gender
        FROM join_requests jr
        JOIN user_profiles p ON p.user_id = jr.user_id
        WHERE jr.activity_id = ? AND jr.user_id = ?
        ORDER BY jr.requested_at DESC
        LIMIT 1
    ");
    $stmt->execute([$activityId, $userId]);
    $row = $stmt->fetch();
    apiSuccess(['request' => $row ? _fmt($row) : null]);
}

// ── ENVIAR solicitud ─────────────────────────────────────────
function submitRequest(): void {
    $session = requireAuth();
    $body    = getBody();

    $activityId = $body['activityId'] ?? null;
    $message    = trim($body['message'] ?? '');

    if (!$activityId) apiError(400, 'activityId es requerido');

    $pdo = getDB();
    _ensureTables($pdo);

    // Verificar que la actividad existe y está activa
    $stmt = $pdo->prepare('SELECT id, organizer_id, title FROM activities WHERE id = ? AND is_active = 1');
    $stmt->execute([$activityId]);
    $act = $stmt->fetch();
    if (!$act) apiError(404, 'Actividad no encontrada o inactiva');
    if ($act['organizer_id'] === $session['user_id']) {
        apiError(400, 'No puedes unirte a tu propia actividad');
    }

    // Verificar que no existe una solicitud pendiente
    $stmt = $pdo->prepare("
        SELECT id FROM join_requests
        WHERE activity_id = ? AND user_id = ? AND status = 'pending'
    ");
    $stmt->execute([$activityId, $session['user_id']]);
    if ($stmt->fetch()) apiError(409, 'Ya tienes una solicitud pendiente');

    $id = _uuid();
    $pdo->prepare("
        INSERT INTO join_requests (id, activity_id, user_id, message, status, requested_at, updated_at)
        VALUES (?, ?, ?, ?, 'pending', NOW(), NOW())
    ")->execute([$id, $activityId, $session['user_id'], $message]);

    // Fetch user name
    $stmtName = $pdo->prepare("SELECT display_name FROM user_profiles WHERE user_id = ?");
    $stmtName->execute([$session['user_id']]);
    $senderName = $stmtName->fetchColumn() ?: 'Alguien';

    // Crear notificación para el organizador
    $notifId = _uuid();
    $notifMessage = "{$senderName} ha solicitado unirse a tu actividad.";
    $pdo->prepare("
        INSERT INTO notifications
        (id, user_id, type, title, body, entity_type, entity_id, created_at)
        VALUES (?, ?, 'join_request', 'Nueva solicitud', ?, 'join_request', ?, NOW())
    ")->execute([
        $notifId, $act['organizer_id'], $notifMessage, $id
    ]);

    // Devolver la solicitud creada
    $stmt = $pdo->prepare("
        SELECT jr.id, jr.activity_id, jr.user_id, jr.message,
               jr.status, jr.requested_at, jr.responded_at,
               jr.responded_by, jr.response_message,
               p.display_name AS user_name, p.profile_image_url AS user_image,
               p.rating AS user_rating, p.birth_date AS user_birth_date,
               p.gender AS user_gender
        FROM join_requests jr JOIN user_profiles p ON p.user_id = jr.user_id WHERE jr.id = ?
    ");
    $stmt->execute([$id]);
    apiSuccess(['request' => _fmt($stmt->fetch())], 201);
}

// ── RESPONDER solicitud ──────────────────────────────────────
function respondToRequest(string $id): void {
    $session = requireAuth();
    $body    = getBody();
    $pdo     = getDB();
    _ensureTables($pdo);

    $accepted        = (bool)($body['accepted'] ?? false);
    $responseMessage = trim($body['responseMessage'] ?? '');

    // Verificar que es el organizador de la actividad
    $stmt = $pdo->prepare("
        SELECT jr.id, jr.user_id, jr.activity_id, a.organizer_id
        FROM join_requests jr
        JOIN activities a ON a.id = jr.activity_id
        WHERE jr.id = ?
    ");
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    if (!$row) apiError(404, 'Solicitud no encontrada');
    if ($row['organizer_id'] !== $session['user_id']) apiError(403, 'Sin permiso');

    $newStatus = $accepted ? 'accepted' : 'rejected';
    $pdo->prepare("
        UPDATE join_requests
        SET status = ?, responded_at = NOW(), responded_by = ?, response_message = ?, updated_at = NOW()
        WHERE id = ?
    ")->execute([$newStatus, $session['user_id'], $responseMessage ?: null, $id]);

    if ($accepted) {
        $notifId = _uuid();
        $notifMessage = "¡Tu solicitud ha sido aceptada! Toca para ir al grupo.";
        $pdo->prepare("
            INSERT INTO notifications 
            (id, user_id, type, title, body, entity_type, entity_id, created_at)
            VALUES (?, ?, 'request_accepted', '¡Solicitud aceptada!', ?, 'activity', ?, NOW())
        ")->execute([
            $notifId, $row['user_id'], $notifMessage, $row['activity_id']
        ]);
    }


    $stmt = $pdo->prepare("
        SELECT jr.id, jr.activity_id, jr.user_id, jr.message,
               jr.status, jr.requested_at, jr.responded_at,
               jr.responded_by, jr.response_message,
               p.display_name AS user_name, p.profile_image_url AS user_image,
               p.rating AS user_rating, p.birth_date AS user_birth_date,
               p.gender AS user_gender
        FROM join_requests jr JOIN user_profiles p ON p.user_id = jr.user_id WHERE jr.id = ?
    ");
    $stmt->execute([$id]);
    apiSuccess(['request' => _fmt($stmt->fetch())]);
}

function _fmt(array $r): array {
    return [
        'id'              => $r['id'],
        'activityId'      => $r['activity_id'],
        'userId'          => $r['user_id'],
        'userName'        => $r['user_name'],
        'userImageUrl'    => $r['user_image'] ?? null,
        'userRating'      => isset($r['user_rating']) ? (float)$r['user_rating'] : 0.0,
        'userBirthDate'   => $r['user_birth_date'] ?? null,
        'userGender'      => $r['user_gender'] ?? null,
        'message'         => $r['message'] ?? '',
        'status'          => $r['status'],
        'requestedAt'     => $r['requested_at'],
        'respondedAt'     => $r['responded_at'] ?? null,
        'respondedBy'     => $r['responded_by'] ?? null,
        'responseMessage' => $r['response_message'] ?? null,
    ];
}

function _uuid(): string {
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

function _ensureTables(PDO $pdo): void {
    // join_requests table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS join_requests (
            id               VARCHAR(36) NOT NULL PRIMARY KEY,
            activity_id      VARCHAR(36) NOT NULL,
            user_id          VARCHAR(36) NOT NULL,
            message          TEXT NULL,
            status           VARCHAR(20) NOT NULL DEFAULT 'pending',
            responded_by     VARCHAR(36) NULL,
            response_message TEXT NULL,
            responded_at     DATETIME NULL,
            requested_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_jr_activity (activity_id),
            INDEX idx_jr_user (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // user_notifications table (en caso de que no haya ejecutado notifications.php antes)
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS user_notifications (
            id             VARCHAR(36)  NOT NULL PRIMARY KEY,
            user_id        VARCHAR(36)  NOT NULL,
            type           VARCHAR(40)  NOT NULL DEFAULT 'newActivity',
            title          VARCHAR(200) NOT NULL,
            message        TEXT         NOT NULL,
            activity_id    VARCHAR(36)  NULL,
            activity_title VARCHAR(200) NULL,
            sender_name    VARCHAR(100) NULL,
            is_read        TINYINT(1)   NOT NULL DEFAULT 0,
            created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_unn_user (user_id, is_read),
            INDEX idx_unn_created (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");
}
