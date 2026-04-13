<?php
require_once __DIR__ . "/config.php";
$pdo = getDB();

$action = $_GET['action'] ?? 'list';
$session = requireAuth();

switch ($action) {
    case 'list':
        $activityId = $_GET['activityId'] ?? null;
        if (!$activityId) apiError(400, "Falta activityId");
        
        $stmt = $pdo->prepare("
            SELECT 
                c.id, c.activity_id, c.title, c.description, c.category, c.is_required, 
                c.assigned_to_user_id, c.assigned_at, c.created_at, c.created_by_user_id,
                u.id as assigned_id,
                up.display_name as assigned_name,
                up.profile_image_url as assigned_image
            FROM contributions c
            LEFT JOIN users u ON u.id = c.assigned_to_user_id
            LEFT JOIN user_profiles up ON up.user_id = u.id
            WHERE c.activity_id = ?
            ORDER BY c.created_at ASC
        ");
        $stmt->execute([$activityId]);
        $rows = $stmt->fetchAll();
        
        $formatted = array_map(function($r) {
            return [
                'id' => $r['id'],
                'activityId' => $r['activity_id'],
                'title' => $r['title'],
                'description' => $r['description'] ?? '',
                'category' => $r['category'] ?? 'other',
                'isRequired' => (bool)$r['is_required'],
                'assignedToUserId' => $r['assigned_to_user_id'],
                'assignedToUserName' => $r['assigned_name'],
                'assignedToUserImage' => $r['assigned_image'],
                'createdAt' => $r['created_at'],
                'createdByUserId' => $r['created_by_user_id']
            ];
        }, $rows);
        
        apiSuccess(['contributions' => $formatted]);
        break;

    case 'assign':
        $body = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $id = $body['contributionId'] ?? null;
        if (!$id) apiError(400, "Falta contributionId");
        
        $stmt = $pdo->prepare("UPDATE contributions SET assigned_to_user_id = ?, assigned_at = NOW() WHERE id = ?");
        $stmt->execute([$session['user_id'], $id]);
        apiSuccess(['message' => 'Asignado']);
        break;
        
    case 'unassign':
        $body = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $id = $body['contributionId'] ?? null;
        if (!$id) apiError(400, "Falta contributionId");
        
        $stmt = $pdo->prepare("UPDATE contributions SET assigned_to_user_id = NULL, assigned_at = NULL WHERE id = ?");
        $stmt->execute([$id]);
        apiSuccess(['message' => 'Desasignado']);
        break;
        
    case 'create':
        $body = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $activityId = $body['activityId'] ?? null;
        $title = $body['title'] ?? null;
        if (!$activityId || !$title) apiError(400, "Faltan datos");
        
        $cid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x', mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000, mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff));
        $desc = $body['description'] ?? '';
        $cat = $body['category'] ?? 'other';
        
        $stmt = $pdo->prepare("INSERT INTO contributions (id, activity_id, created_by_user_id, title, description, category, is_required) VALUES (?, ?, ?, ?, ?, ?, 0)");
        $stmt->execute([$cid, $activityId, $session['user_id'], $title, $desc, $cat]);
        
        apiSuccess(['id' => $cid]);
        break;

    default:
        apiError(400, "Acción no permitida");
}
