# 🗺️ Plan de Implementación — Autenticación, Edad y Consentimiento
## Join App · Fase 2

---

## ✅ Lo que ya está listo

| Componente | Estado |
|---|---|
| BD `joinBD2026` base | ✅ Creada |
| Patch v1.1.0 (OAuth, edad, consentimiento) | ✅ Script listo → `patch_v1_1_0_auth_age_consent.sql` |
| `UserModel` actualizado con `birthDate`, `gender`, `authProviders` | ✅ |

---

## 📋 Flujo completo del usuario nuevo

```
Pantalla splash
     │
     ▼
[LoginScreen / RegisterScreen]
  ├── Botón "Continuar con Google"     → OAuth Google
  ├── Botón "Continuar con Facebook"   → OAuth Facebook  
  └── Botón "Registrarse con email"    → email + contraseña
     │
     ▼
[ConsentScreen] ← OBLIGATORIO antes de continuar
  • Términos y condiciones
  • Política de privacidad
  • Consentimiento de datos (con checkboxes independientes)
  • Verificación de mayoría de edad (>18)
     │
     ▼
[OnboardingScreen] — paso a paso
  • Paso 1: Foto de perfil (cámara / galería / foto OAuth)
  • Paso 2: Nombre + fecha de nacimiento + género
  • Paso 3: Bio (texto libre)
  • Paso 4: Intereses (mínimo 3 tags)
  ──────────────────────
  • Setup completado → ir a MainScreen
     │
     ▼
[MainScreen] ← app normal
```

---

## 🔨 Pasos de implementación Flutter

### PASO 1 — Importar el patch SQL
```
phpMyAdmin → joinBD2026 → Importar → patch_v1_1_0_auth_age_consent.sql
```

### PASO 2 — Instalar dependencias OAuth
```yaml
# pubspec.yaml
dependencies:
  google_sign_in: ^6.2.1       # OAuth Google
  flutter_facebook_auth: ^7.0.1 # OAuth Facebook
  image_picker: ^1.1.2          # Foto de perfil
  image_cropper: ^8.0.2         # Recortar foto (cuadrado)
  flutter_secure_storage: ^9.0.0 # Guardar tokens cifrados
```

### PASO 3 — Pantallas a crear
Todas en `lib/features/auth/presentation/`:

| Archivo | Descripción |
|---|---|
| `register_screen.dart` | Email + contraseña + botones OAuth |
| `consent_screen.dart` | Términos + checkboxes de consentimiento |
| `onboarding_screen.dart` | Configuración de perfil paso a paso |

### PASO 4 — Rutas en GoRouter (`main.dart`)
```dart
GoRoute(path: '/register',   builder: (_, __) => const RegisterScreen()),
GoRoute(path: '/consent',    builder: (_, __) => const ConsentScreen()),
GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
```

### PASO 5 — Lógica en AppState
```dart
// Nuevos métodos a agregar en app_state.dart
Future<bool> loginWithGoogle();
Future<bool> loginWithFacebook();
Future<bool> registerWithEmail(email, password, displayName, birthDate);
Future<void> saveConsents(List<String> consentTypes);
Future<void> updateProfile({String? bio, DateTime? birthDate, ...});
Future<void> uploadProfilePhoto(File photo);
bool get needsOnboarding => !(_currentUser?.setupCompleted ?? true);
```

### PASO 6 — Redirect en GoRouter
```dart
// En el redirect global del router:
if (appState.isLoggedIn && !appState.currentUser!.setupCompleted) {
  return '/onboarding'; // redirigir a completar perfil
}
```

---

## 🔒 Seguridad y cifrado

### Chat E2E (preparación)
- Clave pública/privada por usuario generada en el dispositivo
- Mensajes cifrados con la clave pública del destinatario
- La clave privada NUNCA sale del dispositivo (flutter_secure_storage)
- La BD solo almacena el texto cifrado

### Tokens OAuth
- `access_token` y `refresh_token` de Google/Facebook se cifran con AES-256
  antes de llegar a la BD (columnas `access_token_enc`, `refresh_token_enc`)
- El campo está marcado como `COMMENT 'cifrado AES-256 por la app'` en la BD

### Datos personales
- `birth_date` → cifrada en tránsito (HTTPS/TLS 1.3)
- `password_hash` → solo bcrypt/argon2, costo mínimo 10
- Las fotos de perfil → solo accesibles por URL firmada con expiración

---

## 📱 Pantalla de Consentimiento — Contenido

Los usuarios deben aceptar **obligatoriamente**:
1. ✅ Términos y condiciones (v1.0)
2. ✅ Política de privacidad (v1.0)
3. ✅ Soy mayor de 18 años

Y **opcionales** (pueden rechazar sin perder acceso):
4. ☑ Usar mi ubicación para mostrarme actividades cercanas
5. ☑ Analizar mis intereses para mejorar sugerencias
6. ☑ Recibir notificaciones push
7. ☑ Analytics anónimos para mejorar la app

---

## 🎂 Manejo de edades en actividades

La tabla `activities` ya tiene el campo `age_range VARCHAR(50)`.

### Formatos sugeridos para `age_range`:
| Valor en BD | Significado |
|---|---|
| `Libre` | Sin restricción de edad |
| `18+` | Solo mayores de edad |
| `18-30` | Entre 18 y 30 años |
| `25-40` | Entre 25 y 40 años |
| `40+` | Mayores de 40 años |

### Validación en el backend (PHP/Flutter):
```php
// PHP — validar si el usuario puede unirse a la actividad
function canJoinByAge(User $user, Activity $activity): bool {
    $age = $user->getAge(); // TIMESTAMPDIFF desde birth_date
    $range = $activity->age_range;
    
    if ($range === 'Libre') return true;
    if ($range === '18+') return $age >= 18;
    
    if (str_contains($range, '-')) {
        [$min, $max] = explode('-', $range);
        return $age >= (int)$min && $age <= (int)$max;
    }
    
    if (str_ends_with($range, '+')) {
        $min = (int)rtrim($range, '+');
        return $age >= $min;
    }
    
    return true;
}
```

---

## ⚡ ¿Por dónde empezar ahora?

**Orden recomendado:**
1. `flutter pub add google_sign_in image_picker flutter_secure_storage`
2. Importar el patch SQL en phpMyAdmin
3. Crear `consent_screen.dart` (más sencilla, sin dependencias externas)
4. Crear `register_screen.dart` con email primero, luego agregar OAuth
5. Crear `onboarding_screen.dart` paso a paso
6. Actualizar las rutas y redirect del router
7. Actualizar `AppState` con los nuevos métodos

¿Con cuál pantalla empezamos?
