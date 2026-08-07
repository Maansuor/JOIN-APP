import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_theme.dart';
import 'package:join_app/features/splash/presentation/splash_screen.dart';
import 'package:join_app/features/auth/presentation/login_screen.dart';
import 'package:join_app/features/auth/presentation/onboarding_screen.dart';
import 'package:join_app/features/main/presentation/create_activity_screen.dart';
import 'package:join_app/features/main/presentation/edit_activity_screen.dart';
import 'package:join_app/features/main/presentation/main_screen.dart';
import 'package:join_app/features/main/presentation/hennessy_assistant_screen.dart';
import 'package:join_app/features/activity/presentation/activity_detail_screen.dart';
import 'package:join_app/features/join_requests/presentation/join_requests_screen.dart';
import 'package:join_app/features/activity_group/presentation/activity_group_screen.dart';
import 'package:join_app/features/event_recap/presentation/event_photo_gallery_screen.dart';
import 'package:join_app/features/event_recap/presentation/event_feedback_screen.dart';
import 'package:join_app/core/services/notification_service.dart';
import 'package:join_app/core/models/clan_model.dart';
import 'package:join_app/features/clans/presentation/clan_chat_screen.dart';
import 'package:join_app/features/clans/presentation/clan_info_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Registrar locale en español para timeago
  timeago.setLocaleMessages('es', timeago.EsMessages());
  
  // URL y clave de Supabase — sobreescribibles por entorno:
  //   flutter run --dart-define=SUPABASE_URL=http://127.0.0.1:54321
  //
  // Por defecto se apunta al stack local de Docker. En un dispositivo físico
  // usar 127.0.0.1 junto a `adb reverse tcp:54321 tcp:54321`, ya que 10.0.2.2
  // sólo existe dentro del emulador de Android.
  const urlOverride = String.fromEnvironment('SUPABASE_URL');
  const anonKeyOverride = String.fromEnvironment('SUPABASE_ANON_KEY');

  final supabaseUrl = urlOverride.isNotEmpty
      ? urlOverride
      : kIsWeb
          ? 'http://localhost:54321'
          : (Platform.isAndroid ? 'http://10.0.2.2:54321' : 'http://localhost:54321');

  // Inicializar Supabase con las credenciales locales generadas por Docker
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: anonKeyOverride.isNotEmpty
        ? anonKeyOverride
        : 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );

  // Los buckets de Storage (avatars, activities, chat) se crean en las
  // migraciones: crearlos desde el cliente exigiría privilegios de
  // administrador que la app no tiene ni debe tener.

  // Inicializar notificaciones locales nativas (Paso A)
  await NotificationService.initLocalNotifications();

  // Inicializar datos de locale para intl/DateFormat (es_ES, en_US, etc.)
  await initializeDateFormatting();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const JoinApp(),
    ),
  );
}

class JoinApp extends StatefulWidget {
  const JoinApp({super.key});

  @override
  State<JoinApp> createState() => _JoinAppState();
}

class _JoinAppState extends State<JoinApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/', // La splash decide a dónde ir cuando termina
      // Escucha cambios en AppState para el redirect
      refreshListenable: context.read<AppState>(),
      redirect: (context, state) {
        final appState = context.read<AppState>();
        final location = state.uri.toString();

        // La splash se encarga de su propia salida. Sin esto, en cuanto
        // AppState termina de inicializar el redirect la echaría de la
        // pantalla y la animación se cortaría a media caída.
        if (location == '/') return null;

        // Esperar inicialización completa
        if (!appState.isInitialized) return null;

        final isLoggedIn = appState.isLoggedIn;
        final isLoginRoute = location == '/login';
        final isOnboardingRoute = location.startsWith('/onboarding');
        final isMainRoute = location.startsWith('/main');
        final setupCompleted = appState.currentUser?.setupCompleted ?? false;

        // ── No logueado → a login ────────────────────────────────────
        if (!isLoggedIn) {
          return isLoginRoute ? null : '/login';
        }

        // ── Logueado + setupCompleted → libre en main, bloqueado en login/onboarding
        if (setupCompleted) {
          if (isLoginRoute || isOnboardingRoute) return '/main';
          return null;
        }

        // ── Logueado + sin setup completo → forzar onboarding ─────────
        // No redirigir si ya está en onboarding (evita conflictos internos)
        if (isLoginRoute || (!isOnboardingRoute && !isMainRoute)) {
          return '/onboarding';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        // Onboarding — configuración de perfil post-registro
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/main',
          builder: (context, state) => const MainScreen(),
          routes: [
            GoRoute(
              path: 'hennessy',
              builder: (context, state) => const HennessyAssistantScreen(),
            ),
            GoRoute(
              path: 'activity/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return ActivityDetailScreen(activityId: id);
              },
            ),
            GoRoute(
              path: 'activity/:id/requests',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return JoinRequestsScreen(activityId: id);
              },
            ),
            GoRoute(
              path: 'activity/:id/group',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return ActivityGroupScreen(activityId: id);
              },
            ),
            GoRoute(
              path: 'activity/:id/photos',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return EventPhotoGalleryScreen(activityId: id);
              },
            ),
            GoRoute(
              path: 'activity/:id/feedback',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return EventFeedbackScreen(activityId: id);
              },
            ),
            GoRoute(
              path: 'create',
              builder: (context, state) => const CreateActivityScreen(),
            ),
            GoRoute(
              path: 'activity/:id/edit',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return EditActivityScreen(activityId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/clan/:id/chat',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final clan = state.extra as Clan;
            return ClanChatScreen(clanId: id, clan: clan);
          },
        ),
        GoRoute(
          path: '/clan/:id/info',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final clan = state.extra as Clan;
            return ClanInfoScreen(
              clanId: id,
              clan: clan,
              fromChat: state.uri.queryParameters['fromChat'] == 'true',
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp.router(
      title: 'Join',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
