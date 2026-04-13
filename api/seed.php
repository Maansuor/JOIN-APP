<?php
// ══════════════════════════════════════════════════════════════
//  seed.php  — Genera usuarios de prueba con contraseñas reales
//  Acceder UNA SOLA VEZ: http://localhost/join/api/seed.php
//  Luego ELIMINAR o renombrar este archivo.
// ══════════════════════════════════════════════════════════════
require_once __DIR__ . '/config.php';

// Solo en modo local para seguridad
$host = $_SERVER['HTTP_HOST'] ?? '';
if (!in_array($host, ['localhost', '127.0.0.1', '10.0.2.2'])) {
    apiError(403, 'Seed solo disponible en entorno local');
}

$pdo = getDB();

// Crear tabla user_sessions si no existe (mismo DDL que en auth.php)
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `user_sessions` (
        `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `user_id`    CHAR(36) NOT NULL,
        `token`      VARCHAR(128) NOT NULL,
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `expires_at` DATETIME NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uq_token` (`token`),
        KEY `idx_user` (`user_id`),
        CONSTRAINT `fk_sess_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

// Usuarios de prueba
$users = [
    [
        'id'       => 'user_juan',
        'username' => 'Juan',
        'email'    => 'juan@join.app',
        'password' => 'Garcia',
        'fullName' => 'Juan García',
    ],
    [
        'id'       => 'user_max',
        'username' => 'Max',
        'email'    => 'max@join.app',
        'password' => 'Ortiz',
        'fullName' => 'Max Ortiz',
    ],
];

$created = [];
$updated = [];

foreach ($users as $u) {
    $hash = password_hash($u['password'], PASSWORD_BCRYPT);

    // Revisar si ya existe
    $stmt = $pdo->prepare('SELECT id FROM users WHERE id = ?');
    $stmt->execute([$u['id']]);
    $exists = $stmt->fetch();

    if ($exists) {
        // Actualizar hash (por si el placeholder estaba mal)
        $pdo->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
            ->execute([$hash, $u['id']]);
        $updated[] = $u['username'];
    } else {
        $pdo->prepare("
            INSERT INTO users (id, username, email, password_hash, full_name, is_active, created_at)
            VALUES (?, ?, ?, ?, ?, 1, NOW())
        ")->execute([$u['id'], $u['username'], $u['email'], $hash, $u['fullName']]);
        $created[] = $u['username'];

        // Crear registros relacionados
        $pdo->prepare("INSERT IGNORE INTO user_profiles (user_id) VALUES (?)")->execute([$u['id']]);
        $pdo->prepare("INSERT IGNORE INTO profile_setup_progress (user_id) VALUES (?)")->execute([$u['id']]);
        $pdo->prepare("
            INSERT IGNORE INTO auth_providers (user_id, provider, provider_user_id, created_at)
            VALUES (?, 'email', ?, NOW())
        ")->execute([$u['id'], $u['email']]);
    }
}

// Crear algunas actividades de prueba si la tabla está vacía
$stmt = $pdo->query('SELECT COUNT(*) as n FROM activities');
$count = $stmt->fetch()['n'] ?? 0;

$seededActivities = 0;
if ((int)$count === 0) {
    $activities = [
        [
            'id'               => 'act_001',
            'title'            => 'Trekking al Cerro San Cristóbal',
            'description'      => 'Subida grupal al mirador con vistas panorámicas. Llevar agua y ropa cómoda.',
            'category'         => 'Naturaleza',
            'date_time'        => date('Y-m-d H:i:s', strtotime('+3 days 08:00')),
            'location_name'    => 'Cerro San Cristóbal, Lima',
            'latitude'         => -12.0225,
            'longitude'        => -77.0426,
            'max_participants' => 8,
            'age_range'        => '18-40 años',
            'cost'             => 0,
            'organizer_id'     => 'user_juan',
        ],
        [
            'id'               => 'act_002',
            'title'            => 'Cena italiana en La Trattoria',
            'description'      => 'Noche de pasta artesanal. Precio fijo incluye entrada + plato principal.',
            'category'         => 'Comida',
            'date_time'        => date('Y-m-d H:i:s', strtotime('+5 days 20:00')),
            'location_name'    => 'La Trattoria, Miraflores',
            'latitude'         => -12.1211,
            'longitude'        => -77.0289,
            'max_participants' => 6,
            'age_range'        => '21+ años',
            'cost'             => 65,
            'organizer_id'     => 'user_max',
        ],
        [
            'id'               => 'act_003',
            'title'            => 'Fútbol 5 en cancha de Surco',
            'description'      => 'Partido amistoso. Nivel intermedio. Traer botines o zapatillas deportivas.',
            'category'         => 'Deportes',
            'date_time'        => date('Y-m-d H:i:s', strtotime('+2 days 16:00')),
            'location_name'    => 'Grass Sintético Surco',
            'latitude'         => -12.1426,
            'longitude'        => -76.9929,
            'max_participants' => 10,
            'age_range'        => '18-35 años',
            'cost'             => 15,
            'organizer_id'     => 'user_juan',
        ],
        [
            'id'               => 'act_004',
            'title'            => 'Yoga matutino en el parque',
            'description'      => 'Clase de Hatha Yoga para principiantes y nivel medio. Traer tapete.',
            'category'         => 'Chill',
            'date_time'        => date('Y-m-d H:i:s', strtotime('+1 day 07:00')),
            'location_name'    => 'Parque Kennedy, Miraflores',
            'latitude'         => -12.1230,
            'longitude'        => -77.0307,
            'max_participants' => 12,
            'age_range'        => 'Libre',
            'cost'             => 0,
            'organizer_id'     => 'user_max',
        ],
    ];

    $stmt = $pdo->prepare("
        INSERT INTO activities
            (id, title, description, category, date_time, location_name,
             latitude, longitude, max_participants, age_range, cost,
             organizer_id, is_active, created_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())
    ");

    foreach ($activities as $act) {
        $stmt->execute([
            $act['id'], $act['title'], $act['description'],
            $act['category'], $act['date_time'], $act['location_name'],
            $act['latitude'], $act['longitude'],
            $act['max_participants'], $act['age_range'],
            $act['cost'], $act['organizer_id'],
        ]);
        $seededActivities++;
    }
}

apiSuccess([
    'message'           => '✅ Seed completado',
    'users_created'     => $created,
    'users_updated'     => $updated,
    'activities_seeded' => $seededActivities,
    'note'              => 'Elimina este archivo (api/seed.php) en producción',
]);
