<?php
// ══════════════════════════════════════════════════════════════
//  config.php  — Configuración global del backend Join
//  Incluir en todos los endpoints de la API.
// ══════════════════════════════════════════════════════════════

// Cambia entre 'local' y 'remote'
define('APP_ENV', 'remote');

// ── Configuración según entorno ──────────────────────────────
if (APP_ENV === 'local') {
    define('DB_HOST', 'localhost');
    define('DB_NAME', 'joinBD2026');
    define('DB_USER', 'root');
    define('DB_PASS', '');
    define('DB_CHARSET', 'utf8mb4');

    // XAMPP local desde emulador Android
    define('BASE_URL', 'http://10.0.2.2/join/api');
} else {
    // BD online
    define('DB_HOST', '148.113.206.59'); // usa este solo si tu hosting te dio este IP como host MySQL
    define('DB_NAME', 'vitalife_join');
    define('DB_USER', 'vitalife_nelson');
    define('DB_PASS', 'T1Vsbd8+GSFgF4zy');
    define('DB_CHARSET', 'utf8mb4');

    // Tu backend sigue local en XAMPP
    define('BASE_URL', 'http://10.0.2.2/join/api');
}

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
function getDB(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $dsn = 'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=' . DB_CHARSET;
        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
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
function apiSuccess(array $data = [], int $code = 200): void
{
    http_response_code($code);
    echo json_encode(['success' => true, 'data' => $data], JSON_UNESCAPED_UNICODE);
    exit;
}

function apiError(int $code, string $message): void
{
    http_response_code($code);
    echo json_encode(['success' => false, 'error' => $message], JSON_UNESCAPED_UNICODE);
    exit;
}

// ── Obtener body JSON de la request ─────────────────────────
function getBody(): array
{
    $raw = file_get_contents('php://input');
    return json_decode($raw, true) ?? [];
}

// ── Validar token de sesión (simple — Fase 2: JWT) ──────────
function requireAuth(): array
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];

    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? $_SERVER['HTTP_X_AUTHORIZATION']
        ?? $_GET['token']
        ?? '';

    if (empty($header) && isset($headers['Authorization']))
        $header = $headers['Authorization'];
    if (empty($header) && isset($headers['X-Authorization']))
        $header = $headers['X-Authorization'];

    if (empty($header) && function_exists('getallheaders')) {
        $all = getallheaders();
        $header = $all['Authorization'] ?? $all['authorization'] ?? '';
    }
    if (empty($header) && function_exists('apache_request_headers')) {
        $all = apache_request_headers();
        $header = $all['Authorization'] ?? $all['authorization'] ?? '';
    }

    if (!str_starts_with($header, 'Bearer ')) {
        apiError(401, 'Token requerido');
    }
    $token = trim(substr($header, 7));

    $pdo = getDB();
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