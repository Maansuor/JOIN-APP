<?php
// ══════════════════════════════════════════════════════════════
//  notifications.php  — Notificaciones del usuario
//
//  GET  /api/notifications.php?action=list       → listar
//  POST /api/notifications.php?action=mark_read  → marcar leída
//  POST /api/notifications.php?action=mark_all   → marcar todas
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';

$action = $_GET['action'] ?? 'list';
$method = $_SERVER['REQUEST_METHOD'];

match (true) {
    $action === 'list'      => handleList(),
    $action === 'mark_read' => handleMarkRead(),
    $action === 'mark_all'  => handleMarkAll(),
    $action === 'create'    => handleCreate(),
    default                 => apiError(404, "Acción '$action' no encontrada"),
};

// ── LISTAR NOTIFICACIONES ─────────────────────────────────────
function handleList(): void {
    $session = requireAuth();
    $pdo     = getDB();
    $userId  = $session['user_id'];

    $stmt = $pdo->prepare("
        SELECT n.id, n.type, n.title, n.body AS message, n.is_read, n.created_at,
               CASE 
                 WHEN n.entity_type = 'join_request' THEN jr.activity_id
                 WHEN n.entity_type = 'activity' THEN a_act.id 
                 ELSE n.entity_id 
               END AS activity_id,
               CASE 
                 WHEN n.entity_type = 'join_request' THEN a_jr.title
                 WHEN n.entity_type = 'activity' THEN a_act.title 
                 ELSE NULL
               END AS activity_title,
               CASE 
                 WHEN n.entity_type = 'join_request' THEN p_jr.display_name
                 WHEN n.entity_type = 'activity' THEN p_act.display_name
                 ELSE NULL
               END AS sender_name
        FROM notifications n
        
        LEFT JOIN join_requests jr ON n.entity_type = 'join_request' AND n.entity_id = jr.id
        LEFT JOIN activities a_jr ON jr.activity_id = a_jr.id
        LEFT JOIN user_profiles p_jr ON jr.user_id = p_jr.user_id
        
        LEFT JOIN activities a_act ON n.entity_type = 'activity' AND n.entity_id = a_act.id
        LEFT JOIN user_profiles p_act ON a_act.organizer_id = p_act.user_id
        
        WHERE n.user_id = ?
        ORDER BY n.created_at DESC
        LIMIT 50
    ");
    $stmt->execute([$userId]);
    $rows = $stmt->fetchAll();

    $notifications = array_map(function($r) {
        $typeMap = [
            'join_request' => 'joinRequest',
            'request_accepted' => 'acceptedToGroup',
            'activity_reminder' => 'activityReminder',
            'new_message' => 'newActivity'
        ];
        
        return [
            'id'            => $r['id'],
            'type'          => $typeMap[$r['type']] ?? 'newActivity',
            'title'         => $r['title'],
            'message'       => $r['message'],
            'activityId'    => $r['activity_id'],
            'activityTitle' => $r['activity_title'],
            'senderName'    => $r['sender_name'],
            'isRead'        => (bool)$r['is_read'],
            'timestamp'     => $r['created_at'],
        ];
    }, $rows);

    $unreadCount = count(array_filter($notifications, fn($n) => !$n['isRead']));

    apiSuccess([
        'notifications' => $notifications,
        'unreadCount'   => $unreadCount,
    ]);
}

// ── MARCAR UNA COMO LEÍDA ─────────────────────────────────────
function handleMarkRead(): void {
    $session = requireAuth();
    $pdo     = getDB();
    $body    = getBody();
    $userId  = $session['user_id'];
    $notifId = $body['id'] ?? null;

    if (!$notifId) apiError(400, 'id requerido');

    $pdo->prepare('UPDATE notifications SET is_read = 1, read_at = NOW() WHERE id = ? AND user_id = ?')
        ->execute([$notifId, $userId]);

    apiSuccess(['marked' => true]);
}

// ── MARCAR TODAS COMO LEÍDAS ──────────────────────────────────
function handleMarkAll(): void {
    $session = requireAuth();
    $pdo     = getDB();
    $userId  = $session['user_id'];

    $pdo->prepare('UPDATE notifications SET is_read = 1, read_at = NOW() WHERE user_id = ? AND is_read = 0')
        ->execute([$userId]);

    apiSuccess(['marked' => true]);
}

// ── CREAR NOTIFICACION ───────────────────────────────────────
function handleCreate(): void {
    $session = requireAuth();
    $pdo     = getDB();
    $body    = getBody();
    
    $targetUserId = $body['userId'] ?? null;
    $type         = $body['type'] ?? 'system';
    $title        = $body['title'] ?? 'Nueva Notificación';
    $message      = $body['message'] ?? '';
    // Extra fields if provided by UI (we can map entity_type = 'activity' and entity_id = activityId)
    $activityId   = $body['activityId'] ?? null;
    
    if (!$targetUserId) apiError(400, "Error: userId destinatario faltante");

    $id = sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );

    $stmt = $pdo->prepare("
        INSERT INTO notifications 
        (id, user_id, type, title, body, entity_type, entity_id, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    ");
    
    $entityType = $activityId ? 'activity' : 'system';
    
    $stmt->execute([
        $id, $targetUserId, $type, $title, $message, $entityType, $activityId
    ]);

    apiSuccess(['id' => $id, 'created' => true]);
}
