<?php
// ══════════════════════════════════════════════════════════════
//  chat.php — Controla los mensajes del grupo de una actividad
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/cleanup.php';

$action = $_GET['action'] ?? 'list';
$pdo = getDB();

// Ejecutar limpieza perezosa (lazy cleanup) en segundo plano
try { runCleanup($pdo); } catch (Exception $e) {}

switch ($action) {
    case 'list':
        handleListChat();
        break;
    case 'send':
        handleSendChat();
        break;
    case 'edit':
        handleEditChat();
        break;
    case 'delete':
        handleDeleteChat();
        break;
    case 'react':
        handleReactChat();
        break;
    case 'mark_read':
        handleMarkRead();
        break;
    default:
        apiError(400, "Acción '$action' inválida");
}

function _isParticipant($pdo, $activityId, $userId) {
    // Es organizador
    $stmt1 = $pdo->prepare("SELECT id FROM activities WHERE id = ? AND organizer_id = ?");
    $stmt1->execute([$activityId, $userId]);
    if ($stmt1->fetch()) return true;

    // O es participante aceptado
    $stmt2 = $pdo->prepare("SELECT id FROM join_requests WHERE activity_id = ? AND user_id = ? AND status = 'accepted'");
    $stmt2->execute([$activityId, $userId]);
    return (bool) $stmt2->fetch();
}

// ── GET CHAT MESSAGES ──────────────────────────────────────────
function handleListChat(): void {
    $session = requireAuth();
    $pdo = getDB();
    $userId = $session['user_id'];
    $activityId = $_GET['activityId'] ?? null;

    if (!$activityId) apiError(400, 'Falta activityId');

    // Verificar si el usuario participa
    if (!_isParticipant($pdo, $activityId, $userId)) {
        apiError(403, 'No tienes acceso a este chat');
    }

    $stmt = $pdo->prepare("
        SELECT 
            cm.id, cm.user_id, cm.message, cm.type, cm.sent_at, cm.is_pinned, cm.is_edited,
            up.display_name as user_name, 
            up.profile_image_url as user_image_url,
            a.organizer_id
        FROM chat_messages cm
        JOIN user_profiles up ON up.user_id = cm.user_id
        JOIN activities a ON a.id = cm.activity_id
        WHERE cm.activity_id = ? AND cm.is_deleted = 0
        ORDER BY cm.sent_at DESC
        LIMIT 100
    ");
    $stmt->execute([$activityId]);
    $messages = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Get reactions
    $msgIds = array_column($messages, 'id');
    $reactions = [];
    $reads = [];
    if (!empty($msgIds)) {
        $in = str_repeat('?,', count($msgIds) - 1) . '?';
        $rStmt = $pdo->prepare("SELECT message_id, user_id, reaction FROM chat_message_reactions WHERE message_id IN ($in)");
        $rStmt->execute($msgIds);
        foreach ($rStmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
            $reactions[$r['message_id']][] = [
                'userId' => $r['user_id'],
                'reaction' => $r['reaction']
            ];
        }

        try {
            $rdStmt = $pdo->prepare("
                SELECT r.message_id, r.user_id, r.read_at, p.display_name 
                FROM chat_message_reads r
                JOIN user_profiles p ON p.user_id = r.user_id
                WHERE r.message_id IN ($in)
            ");
            $rdStmt->execute($msgIds);
            foreach ($rdStmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
                $reads[$r['message_id']][] = [
                    'userId' => $r['user_id'],
                    'userName' => $r['display_name'],
                    'readAt' => $r['read_at']
                ];
            }
        } catch (Exception $e) {}
    }
    // Mapear fotos si es necesario (type='image')
    foreach ($messages as &$msg) {
        if ($msg['type'] === 'image') {
            $imgStmt = $pdo->prepare("SELECT image_url FROM chat_message_images WHERE message_id = ?");
            $imgStmt->execute([$msg['id']]);
            $msg['image_url'] = $imgStmt->fetchColumn();
        }
        // Compatibilidad con el modelo de flutter
        $msg['userName'] = $msg['user_name'];
        $msg['userImageUrl'] = $msg['user_image_url'] ?? 'assets/images/placeholder.png';
        $msg['timestamp'] = $msg['sent_at'];
        $msg['isPinned'] = (bool) $msg['is_pinned'];
        $msg['isEdited'] = (bool) ($msg['is_edited'] ?? 0);
        $msg['organizerId'] = $msg['organizer_id'];
        $msg['reactions'] = $reactions[$msg['id']] ?? [];
        $msg['readBy'] = $reads[$msg['id']] ?? [];
    }

    apiSuccess([
        'messages' => $messages // Ya ordenado cronológicamente por Firestore-like ListView (reverse: true)
    ]);
}

// ── SEND CHAT MESSAGE ──────────────────────────────────────────
function handleSendChat(): void {
    $session = requireAuth();
    $pdo = getDB();
    $userId = $session['user_id'];
    
    // Obtener campos de form-data o raw
    $activityId = $_POST['activityId'] ?? (getBody()['activityId'] ?? null);
    $message = $_POST['message'] ?? (getBody()['message'] ?? '');
    
    if (!$activityId) apiError(400, 'Falta activityId');
    if (trim($message) === '' && empty($_FILES['photo'])) apiError(400, 'El mensaje o foto no puede estar vacío');

    if (!_isParticipant($pdo, $activityId, $userId)) {
        apiError(403, 'No tienes permiso para escribir en este chat');
    }

    $msgId = genUUID();
    $type = 'text';

    // Manejar subida de foto
    $imageUrl = null;
    if (isset($_FILES['photo']) && $_FILES['photo']['error'] === UPLOAD_ERR_OK) {
        $type = 'image';
        $uploadDir = __DIR__ . '/../uploads/chat/';
        if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);

        $tmpName = $_FILES['photo']['tmp_name'];
        $ext = strtolower(pathinfo($_FILES['photo']['name'], PATHINFO_EXTENSION));
        // Validar extension ($ext == 'jpg' || $ext == 'png'...)
        
        $filename = 'msg_' . $msgId . '.' . $ext;
        $destPath = $uploadDir . $filename;
        
        if (move_uploaded_file($tmpName, $destPath)) {
            $imageUrl = BASE_URL . '/../uploads/chat/' . $filename;
        } else {
            apiError(500, 'Error al subir la imagen');
        }
    }

    $pdo->beginTransaction();
    try {
        $pdo->prepare("
            INSERT INTO chat_messages (id, activity_id, user_id, message, type, sent_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ")->execute([$msgId, $activityId, $userId, $message, $type]);

        if ($imageUrl) {
            $pdo->prepare("
                INSERT INTO chat_message_images (message_id, image_url)
                VALUES (?, ?)
            ")->execute([$msgId, $imageUrl]);
        }

        $pdo->commit();

        // Notificar a los demas
        $membersStmt = $pdo->prepare("
            SELECT user_id FROM join_requests WHERE activity_id = ? AND status = 'accepted'
            UNION
            SELECT organizer_id AS user_id FROM activities WHERE id = ?
        ");
        $membersStmt->execute([$activityId, $activityId]);
        $members = $membersStmt->fetchAll(PDO::FETCH_COLUMN);

        $stmtName = $pdo->prepare("SELECT display_name FROM user_profiles WHERE user_id = ?");
        $stmtName->execute([$userId]);
        $senderName = $stmtName->fetchColumn() ?: 'Alguien';

        $stmtNotif = $pdo->prepare("
            INSERT INTO notifications (id, user_id, type, title, body, entity_type, entity_id, created_at)
            VALUES (?, ?, 'new_message', ?, ?, 'activity', ?, NOW())
        ");
        
        $titleNotif = "Nuevo mensaje de " . htmlspecialchars($senderName);
        $bodyNotif = ($type === 'image') ? "📷 Envió una imagen" : "💬 Envió un mensaje nuevo en el grupo.";
        
        foreach ($members as $memberId) {
            if ($memberId !== $userId) {
                $stmtNotif->execute([genUUID(), $memberId, $titleNotif, $bodyNotif, $activityId]);
            }
        }

    } catch (Exception $e) {
        $pdo->rollBack();
        if ($imageUrl && file_exists($destPath)) @unlink($destPath);
        apiError(500, 'Error guardando mensaje: ' . $e->getMessage());
    }

    apiSuccess([
        'id' => $msgId,
        'message' => $message,
        'type' => $type,
        'imageUrl' => $imageUrl
    ]);
}

// ── EDIT CHAT MESSAGE ──────────────────────────────────────────
function handleEditChat(): void {
    $session = requireAuth();
    $pdo = getDB();
    $userId = $session['user_id'];
    $body = getBody();
    
    $messageId = $body['messageId'] ?? null;
    $newMessage = $body['message'] ?? '';
    
    if (!$messageId) apiError(400, 'Falta messageId');
    if (trim($newMessage) === '') apiError(400, 'El mensaje no puede estar vacío');
    
    $stmt = $pdo->prepare("SELECT user_id, sent_at FROM chat_messages WHERE id = ? AND is_deleted = 0");
    $stmt->execute([$messageId]);
    $msg = $stmt->fetch();
    
    if (!$msg) apiError(404, 'Mensaje no encontrado');
    if ($msg['user_id'] !== $userId) apiError(403, 'No puedes editar mensajes de otros');
    
    $sentTime = strtotime($msg['sent_at']);
    $now = time();
    if ($now - $sentTime > 50) {
        apiError(403, 'Solo puedes editar un mensaje dentro de los primeros 50 segundos');
    }
    
    $pdo->prepare("UPDATE chat_messages SET message = ?, is_edited = 1 WHERE id = ?")->execute([$newMessage, $messageId]);
    apiSuccess(['message' => 'Mensaje editado']);
}

// ── DELETE CHAT MESSAGE ────────────────────────────────────────
function handleDeleteChat(): void {
    $session = requireAuth();
    $pdo = getDB();
    $userId = $session['user_id'];
    $body = getBody();
    
    $messageId = $body['messageId'] ?? null;
    if (!$messageId) apiError(400, 'Falta messageId');
    
    $stmt = $pdo->prepare("
        SELECT cm.user_id, a.organizer_id 
        FROM chat_messages cm
        JOIN activities a ON a.id = cm.activity_id
        WHERE cm.id = ? AND cm.is_deleted = 0
    ");
    $stmt->execute([$messageId]);
    $msg = $stmt->fetch();
    
    if (!$msg) apiError(404, 'Mensaje no encontrado');
    
    if ($msg['user_id'] !== $userId && $msg['organizer_id'] !== $userId) {
        apiError(403, 'No tienes permiso para eliminar este mensaje');
    }
    
    $pdo->prepare("UPDATE chat_messages SET is_deleted = 1, deleted_at = NOW() WHERE id = ?")->execute([$messageId]);
    apiSuccess(['message' => 'Mensaje eliminado']);
}

// ── REACT TO CHAT MESSAGE ──────────────────────────────────────
function handleReactChat(): void {
    $session = requireAuth();
    $pdo = getDB();
    $userId = $session['user_id'];
    $body = getBody();
    
    $messageId = $body['messageId'] ?? null;
    $reaction = $body['reaction'] ?? null;
    
    if (!$messageId || !$reaction) apiError(400, 'Faltan parámetros');
    
    $stmt = $pdo->prepare("SELECT id, reaction FROM chat_message_reactions WHERE message_id = ? AND user_id = ?");
    $stmt->execute([$messageId, $userId]);
    $existing = $stmt->fetch();
    
    if ($existing) {
        if ($existing['reaction'] === $reaction) {
            $pdo->prepare("DELETE FROM chat_message_reactions WHERE id = ?")->execute([$existing['id']]);
            apiSuccess(['action' => 'removed']);
        } else {
            $pdo->prepare("UPDATE chat_message_reactions SET reaction = ?, created_at = NOW() WHERE id = ?")->execute([$reaction, $existing['id']]);
            apiSuccess(['action' => 'updated']);
        }
    } else {
        $id = genUUID();
        $pdo->prepare("INSERT INTO chat_message_reactions (id, message_id, user_id, reaction, created_at) VALUES (?, ?, ?, ?, NOW())")->execute([$id, $messageId, $userId, $reaction]);
        apiSuccess(['action' => 'added']);
    }
}


function genUUID(): string {
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

// ── MARK CHAT MESSAGES AS READ ─────────────────────────────────
function handleMarkRead(): void {
    $session = requireAuth();
    $pdo = getDB();
    $userId = $session['user_id'];
    $body = getBody();
    
    $activityId = $body['activityId'] ?? null;
    if (!$activityId) apiError(400, 'Falta activityId');

    // Create table if not exists (lazy)
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS chat_message_reads (
            message_id VARCHAR(36) NOT NULL,
            user_id VARCHAR(36) NOT NULL,
            read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (message_id, user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    $stmt = $pdo->prepare("
        INSERT IGNORE INTO chat_message_reads (message_id, user_id)
        SELECT id, ? FROM chat_messages 
        WHERE activity_id = ? AND user_id != ? AND is_deleted = 0
    ");
    $stmt->execute([$userId, $activityId, $userId]);
    
    apiSuccess(['marked' => true]);
}
