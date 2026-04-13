<?php
// ══════════════════════════════════════════════════════════════
//  activities.php  — CRUD de actividades
//  GET    /api/activities.php              → listar
//  GET    /api/activities.php?id=X         → detalle
//  POST   /api/activities.php              → crear
//  PUT    /api/activities.php?id=X         → actualizar
//  DELETE /api/activities.php?id=X         → cancelar
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/cleanup.php';

// Asegurar que las columnas existan
$pdo = getDB();

try { runCleanup($pdo); } catch (Exception $e) {}

try {
    $pdo->exec("ALTER TABLE activities ADD COLUMN duration_minutes INT NULL DEFAULT NULL");
} catch(Exception $e) {}
try {
    $pdo->exec("ALTER TABLE activities ADD COLUMN cost DECIMAL(10,2) NULL DEFAULT 0.00");
} catch(Exception $e) {}
try {
    $pdo->exec("ALTER TABLE activities ADD COLUMN tags VARCHAR(255) NULL DEFAULT NULL");
} catch(Exception $e) {}

$method = $_SERVER['REQUEST_METHOD'];
if ($method === 'POST' && isset($_POST['_method']) && strtoupper($_POST['_method']) === 'PUT') {
    $method = 'PUT';
}
$id     = $_GET['id'] ?? null;

match (true) {
    $method === 'GET'    && !$id => listActivities(),
    $method === 'GET'    &&  $id => getActivity($id),
    $method === 'POST'           => createActivity(),
    $method === 'PUT'    &&  $id => updateActivity($id),
    $method === 'DELETE' &&  $id => cancelActivity($id),
    default => apiError(405, 'Método no permitido'),
};

// ── LISTAR ───────────────────────────────────────────────────
function listActivities(): void {
    $pdo      = getDB();
    
    // Limpieza automática: borrar datos/imagen 1 hora después de finalizar
    // Asumimos que "finaliza" = event_datetime + duration_minutes. Por simplicidad usamos event_datetime + 3 hours (2 hours duration + 1 hour)
    // Pero si quieren "1 hora despues de finalizada", podemos expirar activities.
    $oldSt = $pdo->query("SELECT id, cover_image_url FROM activities WHERE is_active = 1 AND DATE_ADD(event_datetime, INTERVAL COALESCE(duration_minutes, 120)+60 MINUTE) < NOW()");
    while ($old = $oldSt->fetch()) {
        if (!empty($old['cover_image_url']) && str_starts_with($old['cover_image_url'], 'http')) {
            $filename = basename($old['cover_image_url']);
            $filePath = __DIR__ . '/../uploads/activities/' . $filename;
            if (file_exists($filePath)) {
                @unlink($filePath);
            }
        }
        $pdo->prepare("UPDATE activities SET is_active = 0, cover_image_url = NULL WHERE id = ?")->execute([$old['id']]);
    }

    $category = $_GET['category'] ?? null;
    $search   = $_GET['search']   ?? null;
    $limit    = min((int)($_GET['limit'] ?? 50), 100);
    $offset   = (int)($_GET['offset'] ?? 0);

    $where  = ['a.is_active = 1'];
    $params = [];

    if ($category && $category !== 'Todos') {
        $where[]  = 'a.category = ?';
        $params[] = $category;
    }
    if ($search) {
        $where[]  = '(a.title LIKE ? OR a.description LIKE ?)';
        $params[] = "%$search%";
        $params[] = "%$search%";
    }

    $whereClause = implode(' AND ', $where);

    $stmt = $pdo->prepare("
        SELECT
            a.id, a.title, a.description, a.category,
            a.event_datetime, a.location_name, a.latitude, a.longitude,
            a.max_participants, a.age_range, a.is_active, a.created_at,
            a.cover_image_url, a.duration_minutes, a.cost, a.tags,
            u.id AS organizer_id,
            up.display_name AS organizer_name,
            up.profile_image_url AS organizer_image,
            up.rating AS organizer_rating,
            (SELECT COUNT(*) FROM join_requests jr
             WHERE jr.activity_id = a.id AND jr.status = 'accepted') AS participant_count
        FROM activities a
        JOIN users u ON u.id = a.organizer_id
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE $whereClause
        ORDER BY a.event_datetime ASC
        LIMIT $limit OFFSET $offset
    ");
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    apiSuccess([
        'activities' => array_map('_formatActivity', $rows),
        'total'      => count($rows),
        'limit'      => $limit,
        'offset'     => $offset,
    ]);
}

// ── DETALLE ─────────────────────────────────────────────────
function getActivity(string $id): void {
    $pdo  = getDB();
    $stmt = $pdo->prepare("
        SELECT
            a.id, a.title, a.description, a.category,
            a.event_datetime, a.location_name, a.latitude, a.longitude,
            a.max_participants, a.age_range, a.is_active, a.created_at,
            a.cover_image_url, a.duration_minutes, a.cost, a.tags,
            u.id AS organizer_id,
            up.display_name AS organizer_name,
            up.profile_image_url AS organizer_image,
            up.rating AS organizer_rating,
            (SELECT COUNT(*) FROM join_requests jr
             WHERE jr.activity_id = a.id AND jr.status = 'accepted') AS participant_count
        FROM activities a
        JOIN users u ON u.id = a.organizer_id
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE a.id = ?
    ");
    $stmt->execute([$id]);
    $row = $stmt->fetch();

    if (!$row) apiError(404, 'Actividad no encontrada');
    apiSuccess(['activity' => _formatActivity($row)]);
}

// ── CREAR ────────────────────────────────────────────────────
function createActivity(): void {
    $session = requireAuth();
    $body = json_decode(file_get_contents('php://input'), true) ?: $_POST;
    
    // Parsear contributions si vienen como string JSON (multipart)
    if (isset($body['contributions']) && is_string($body['contributions'])) {
        $body['contributions'] = json_decode($body['contributions'], true) ?: [];
    }

    $required = ['title', 'description', 'category', 'dateTime',
                 'locationName', 'maxParticipants'];
    foreach ($required as $field) {
        if (empty($body[$field])) apiError(400, "Campo requerido: $field");
    }

    $pdo = getDB();
    $id  = _uuid();

    $imageUrl = $body['imageUrl'] ?? null;
    if (isset($_FILES['photo'])) {
        error_log("Upload intent: " . print_r($_FILES['photo'], true));
        if ($_FILES['photo']['error'] === UPLOAD_ERR_OK) {
            $uploadDir = __DIR__ . '/../uploads/activities/';
            if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);
            $ext = strtolower(pathinfo($_FILES['photo']['name'], PATHINFO_EXTENSION));
            $filename = 'act_' . $id . '.' . $ext;
            if (move_uploaded_file($_FILES['photo']['tmp_name'], $uploadDir . $filename)) {
                $imageUrl = str_replace('/api', '', BASE_URL) . '/uploads/activities/' . $filename;
                error_log("Upload success: $imageUrl");
            } else {
                error_log("move_uploaded_file failed.");
            }
        }
    }

    $pdo->prepare("
        INSERT INTO activities (
            id, title, description, category, event_datetime, event_date, event_time,
            location_name, latitude, longitude,
            max_participants, age_range, cover_image_url,
            duration_minutes, cost, tags, organizer_id,
            is_active, created_at
        ) VALUES (
            ?, ?, ?, ?, ?, DATE(?), TIME(?),
            ?, ?, ?,
            ?, ?, ?,
            ?, ?, ?, ?,
            1, NOW()
        )
    ")->execute([
        $id,
        $body['title'],
        $body['description'],
        $body['category'],
        $body['dateTime'],
        $body['dateTime'],
        $body['dateTime'],
        $body['locationName'],
        $body['latitude']  ?? null,
        $body['longitude'] ?? null,
        (int)$body['maxParticipants'],
        $body['ageRange'] ?? null,
        $imageUrl,
        $body['durationMinutes'] ?? null,
        $body['cost'] ?? 0,
        $body['tags'] ?? null,
        $session['user_id'],
    ]);

    if (isset($body['contributions']) && is_array($body['contributions'])) {
        $stmtCont = $pdo->prepare("INSERT INTO contributions (id, activity_id, created_by_user_id, title, category, is_required) VALUES (?, ?, ?, ?, 'other', 0)");
        foreach ($body['contributions'] as $c) {
            $stmtCont->execute([_uuid(), $id, $session['user_id'], $c]);
        }
    }

    // Devuelve la actividad completa
    getActivity($id);
}

// ── ACTUALIZAR ───────────────────────────────────────────────
function updateActivity(string $id): void {
    $session = requireAuth();
    $pdo     = getDB();
    $body = json_decode(file_get_contents('php://input'), true) ?: $_POST;
    
    if (isset($body['contributions']) && is_string($body['contributions'])) {
        $body['contributions'] = json_decode($body['contributions'], true) ?: [];
    }

    // Verificar que es el organizador
    $stmt = $pdo->prepare('SELECT organizer_id FROM activities WHERE id = ?');
    $stmt->execute([$id]);
    $act = $stmt->fetch();
    if (!$act) apiError(404, 'Actividad no encontrada');
    if ($act['organizer_id'] !== $session['user_id']) apiError(403, 'Sin permiso');

    $fields = [];
    $params = [];
    $map = [
        'title'           => 'title',
        'description'     => 'description',
        'category'        => 'category',
        'dateTime'        => 'event_datetime',
        'locationName'    => 'location_name',
        'latitude'        => 'latitude',
        'longitude'       => 'longitude',
        'maxParticipants' => 'max_participants',
        'ageRange'        => 'age_range',
        'imageUrl'        => 'cover_image_url',
        'durationMinutes' => 'duration_minutes',
        'cost'            => 'cost',
        'tags'            => 'tags',
    ];

    foreach ($map as $bodyKey => $dbCol) {
        if (isset($body[$bodyKey])) {
            $fields[] = "$dbCol = ?";
            $params[] = $body[$bodyKey];
        }
    }

    if (isset($_FILES['photo'])) {
        error_log("Update Upload intent: " . print_r($_FILES['photo'], true));
        if ($_FILES['photo']['error'] === UPLOAD_ERR_OK) {
            $uploadDir = __DIR__ . '/../uploads/activities/';
            if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);
            $ext = strtolower(pathinfo($_FILES['photo']['name'], PATHINFO_EXTENSION));
            $filename = 'act_' . $id . '_' . time() . '.' . $ext;
            if (move_uploaded_file($_FILES['photo']['tmp_name'], $uploadDir . $filename)) {
                $fields[] = "cover_image_url = ?";
                $params[] = str_replace('/api', '', BASE_URL) . '/uploads/activities/' . $filename;
                error_log("Update upload success.");
            }
        }
    }

    if (empty($fields)) apiError(400, 'Nada que actualizar');

    $params[] = $id;
    $pdo->prepare('UPDATE activities SET ' . implode(', ', $fields) . ' WHERE id = ?')
        ->execute($params);

    if (isset($body['contributions']) && is_array($body['contributions'])) {
        $pdo->prepare("DELETE FROM contributions WHERE activity_id = ?")->execute([$id]);
        $stmtCont = $pdo->prepare("INSERT INTO contributions (id, activity_id, created_by_user_id, title, category, is_required) VALUES (?, ?, ?, ?, 'other', 0)");
        foreach ($body['contributions'] as $c) {
            $stmtCont->execute([_uuid(), $id, $session['user_id'], $c]);
        }
    }

    getActivity($id);
}

// ── CANCELAR ────────────────────────────────────────────────
function cancelActivity(string $id): void {
    $session = requireAuth();
    $pdo     = getDB();

    $stmt = $pdo->prepare('SELECT organizer_id FROM activities WHERE id = ?');
    $stmt->execute([$id]);
    $act = $stmt->fetch();
    if (!$act) apiError(404, 'Actividad no encontrada');
    if ($act['organizer_id'] !== $session['user_id']) apiError(403, 'Sin permiso');

    $pdo->prepare('UPDATE activities SET is_active = 0 WHERE id = ?')->execute([$id]);
    apiSuccess(['message' => 'Actividad cancelada']);
}

// ── Formatear actividad ──────────────────────────────────────
function _formatActivity(array $row): array {
    static $pdo = null;
    if (!$pdo) $pdo = getDB();

    $contributions = [];
    if (!empty($row['id'])) {
        $stmt = $pdo->prepare("SELECT title FROM contributions WHERE activity_id = ?");
        $stmt->execute([$row['id']]);
        $contributions = $stmt->fetchAll(PDO::FETCH_COLUMN) ?: [];
    }

    return [
        'id'               => $row['id'],
        'title'            => $row['title'],
        'description'      => $row['description'],
        'category'         => $row['category'],
        'dateTime'         => $row['event_datetime'],
        'locationName'     => $row['location_name'],
        'latitude'         => $row['latitude'] ? (float)$row['latitude'] : null,
        'longitude'        => $row['longitude'] ? (float)$row['longitude'] : null,
        'maxParticipants'  => (int)$row['max_participants'],
        'participantCount' => (int)($row['participant_count'] ?? 0),
        'ageRange'         => $row['age_range'] ?? null,
        'isActive'         => (bool)$row['is_active'],
        'imageUrl'         => $row['cover_image_url'] ?? null,
        'durationMinutes'  => $row['duration_minutes'] ? (int)$row['duration_minutes'] : null,
        'cost'             => $row['cost'] ? (float)$row['cost'] : 0.0,
        'tags'             => $row['tags'] ? explode(',', $row['tags']) : [],
        'contributions'    => $contributions,
        'createdAt'        => $row['created_at'],
        'organizerId'      => $row['organizer_id'],
        'organizerName'    => $row['organizer_name'],
        'organizerImage'   => $row['organizer_image'] ?? null,
        'organizerRating'  => $row['organizer_rating'] ? (float)$row['organizer_rating'] : 0.0,
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
