<?php
// ══════════════════════════════════════════════════════════════
//  cleanup.php — Elimina actividades finalizadas y sus fotos
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';

function runCleanup(PDO $pdo): void {
    try {
        // Encontrar actividades que terminaron hace más de 1 hora
        // (event_datetime + duration_minutes + 60 mins < AHORA)
        $stmt = $pdo->query("
            SELECT id, cover_image_url 
            FROM activities 
            WHERE DATE_ADD(event_datetime, INTERVAL (IFNULL(duration_minutes, 120) + 60) MINUTE) < NOW()
        ");
        $expiredActivities = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if (empty($expiredActivities)) return;

        $uploadDirActivities = __DIR__ . '/../uploads/activities/';
        $uploadDirChat = __DIR__ . '/../uploads/chat/';

        foreach ($expiredActivities as $act) {
            $actId = $act['id'];
            
            // 1. Borrar cover image si es local
            if (!empty($act['cover_image_url']) && strpos($act['cover_image_url'], 'uploads/activities') !== false) {
                $filename = basename($act['cover_image_url']);
                $path = $uploadDirActivities . $filename;
                if (file_exists($path)) {
                    @unlink($path);
                }
            }

            // 2. Encontrar imágenes del chat para esta actividad
            $chatStmt = $pdo->prepare("
                SELECT cmi.image_url 
                FROM chat_message_images cmi
                JOIN chat_messages cm ON cm.id = cmi.message_id
                WHERE cm.activity_id = ?
            ");
            $chatStmt->execute([$actId]);
            $chatImages = $chatStmt->fetchAll(PDO::FETCH_ASSOC);

            foreach ($chatImages as $img) {
                if (!empty($img['image_url'])) {
                    $filename = basename($img['image_url']);
                    $path = $uploadDirChat . $filename;
                    if (file_exists($path)) {
                        @unlink($path);
                    }
                }
            }
        }

        // 3. Borrar de la base de datos (CASCADE borrará chat_messages, requests, etc.)
        $pdo->exec("
            DELETE FROM activities 
            WHERE DATE_ADD(event_datetime, INTERVAL (IFNULL(duration_minutes, 120) + 60) MINUTE) < NOW()
        ");

    } catch (Exception $e) {
        // Silencioso, no queremos que rompa el endpoint
        error_log("Cleanup error: " . $e->getMessage());
    }
}
