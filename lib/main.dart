import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:join_app/core/providers/app_state.dart';
import 'package:join_app/core/theme/app_theme.dart';
import 'package:join_app/features/auth/presentation/login_screen.dart';
import 'package:join_app/features/auth/presentation/onboarding_screen.dart';
import 'package:join_app/features/main/presentation/create_activity_screen.dart';
import 'package:join_app/features/main/presentation/edit_activity_screen.dart';
import 'package:join_app/features/main/presentation/main_screen.dart';
import 'package:join_app/features/activity/presentation/activity_detail_screen.dart';
import 'package:join_app/features/join_requests/presentation/join_requests_screen.dart';
import 'package:join_app/features/activity_group/presentation/activity_group_screen.dart';
import 'package:join_app/features/event_recap/presentation/event_photo_gallery_screen.dart';
import 'package:join_app/features/event_recap/presentation/event_feedback_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      initialLocation: '/login',
      // Escucha cambios en AppState para el redirect
      refreshListenable: context.read<AppState>(),
      redirect: (context, state) {
        final appState = context.read<AppState>();

        // Esperar inicialización completa
        if (!appState.isInitialized) return null;

        final isLoggedIn = appState.isLoggedIn;
        final location = state.uri.toString();
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
    return MaterialApp.router(
      title: 'Join',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
