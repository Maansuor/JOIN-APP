<?php
// ══════════════════════════════════════════════════════════════
//  config.php  — Configuración global del backend Join
//  Incluir en todos los endpoints de la API.
// ══════════════════════════════════════════════════════════════

define('DB_HOST', 'localhost');
define('DB_NAME', 'joinBD2026');
define('DB_USER', 'root');
define('DB_PASS', '');
define('DB_CHARSET', 'utf8mb4');

// URL base para imágenes/assets servidos por XAMPP
define('BASE_URL', 'http://10.0.2.2/join/api');  // 10.0.2.2 = localhost desde emulador Android

// Devuelve siempre JSON
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ── Conexión PDO ─────────────────────────────────────────────
function getDB(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=' . DB_CHARSET;
        $options = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ];
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            apiError(503, 'Database connection failed: ' . $e->getMessage());
        }
    }
    return $pdo;
}

// ── Helpers de respuesta ─────────────────────────────────────
function apiSuccess(array $data = [], int $code = 200): void {
    http_response_code($code);
    echo json_encode(['success' => true, 'data' => $data], JSON_UNESCAPED_UNICODE);
    exit;
}

function apiError(int $code, string $message): void {
    http_response_code($code);
    echo json_encode(['success' => false, 'error' => $message], JSON_UNESCAPED_UNICODE);
    exit;
}

// ── Obtener body JSON de la request ─────────────────────────
function getBody(): array {
    $raw = file_get_contents('php://input');
    return json_decode($raw, true) ?? [];
}

// ── Validar token de sesión (simple — Fase 2: JWT) ──────────
function requireAuth(): array {
    // Log para depuración
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    
    // Fallback: Apache suele borrar 'Authorization'. Probamos alternativas.
    $header = $_SERVER['HTTP_AUTHORIZATION'] 
           ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
           ?? $_SERVER['HTTP_X_AUTHORIZATION']
           ?? $_GET['token']                  // Último recurso para debug
           ?? '';

    if (empty($header) && isset($headers['Authorization'])) $header = $headers['Authorization'];
    if (empty($header) && isset($headers['X-Authorization'])) $header = $headers['X-Authorization'];

    if (empty($header) && function_exists('getallheaders')) {
        $all    = getallheaders();
        $header = $all['Authorization'] ?? $all['authorization'] ?? '';
    }
    if (empty($header) && function_exists('apache_request_headers')) {
        $all    = apache_request_headers();
        $header = $all['Authorization'] ?? $all['authorization'] ?? '';
    }

    if (!str_starts_with($header, 'Bearer ')) {
        apiError(401, 'Token requerido');
    }
    $token = trim(substr($header, 7));

    $pdo = getDB();
    // La columna real en user_sessions es token_hash (schema joinBD2026)
    $stmt = $pdo->prepare(
        'SELECT id, user_id FROM user_sessions
         WHERE token_hash = ? AND expires_at > NOW() AND revoked = 0'
    );
    $stmt->execute([$token]);
    $session = $stmt->fetch();

    if (!$session) {
        apiError(401, 'Sesión inválida o expirada');
    }
    return $session;
}
