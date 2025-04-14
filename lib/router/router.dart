import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/models/auth_state.dart';
import 'package:stock_app/pages/account_page.dart';
import 'package:stock_app/pages/auth_page.dart';
import 'package:stock_app/pages/charts_page.dart';
import 'package:stock_app/pages/history_page.dart';
import 'package:stock_app/pages/kyc_pending_page.dart';
import 'package:stock_app/pages/on_boarding.dart';
import 'package:stock_app/pages/sign_in_page.dart';
import 'package:stock_app/pages/sign_up_page.dart';
import 'package:stock_app/pages/trade_page.dart';
import 'package:stock_app/pages/transactions_page.dart';
import 'package:stock_app/pages/user_details_page.dart';
import 'package:stock_app/pages/watchlist_page.dart';
import 'package:stock_app/pages/admin/pages/admin_login_page.dart';
import 'package:stock_app/pages/admin/payment_verification_page.dart';
import 'package:stock_app/providers/auth_state_provider.dart';
import 'package:stock_app/providers/kyc_status_provider.dart';
import 'package:stock_app/services/user_exists_provider.dart';
import 'package:stock_app/layouts/mobile_layout.dart';
import 'package:stock_app/layouts/desktop_layout.dart';
import 'package:stock_app/layouts/admin_layout.dart';
import 'package:stock_app/widgets/responsive_layout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Router provider that can be used throughout the app
final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state to rebuild router when auth state changes
  final authState = ref.watch(authStateNotifierProvider);
  
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Get the current path
      final path = state.matchedLocation;
      
      // If we're on the auth page and user is authenticated, redirect to home
      if (path == '/' && authState.status == AuthStatus.authenticated) {
        return '/home';
      }
      
      // If we're on a protected route and user is not authenticated, redirect to auth
      if (path != '/' && path != '/signup' && authState.status == AuthStatus.unauthenticated) {
        return '/';
      }
      
      // If user is authenticated but doesn't exist in the database, redirect to onboarding
      if (authState.status == AuthStatus.authenticated) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          // Check if user exists in database
          final userExistsAsync = ref.watch(userExistsProvider(currentUser.id));
          
          return userExistsAsync.when(
            data: (exists) {
              if (!exists && path != '/onboarding') {
                return '/onboarding';
              }
              
              // If user exists, check KYC status
              if (exists && path != '/kyc-pending') {
                final kycStatusAsync = ref.watch(kycStatusProvider);
                
                return kycStatusAsync.when(
                  data: (isKycVerified) {
                    // If KYC is not verified and not already on the KYC pending page, redirect
                    if (!isKycVerified && path != '/kyc-pending') {
                      return '/kyc-pending';
                    }
                    return null;
                  },
                  loading: () => null,
                  error: (_, __) => '/',
                );
              }
              
              return null;
            },
            loading: () => null,
            error: (_, __) => '/',
          );
        }
      }
      
      // No redirect needed
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(path: '/signin',
      builder: (context, state) => const SignInPage(),
      ),
      // Onboarding route
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnBoarding(),
      ),
      
      // KYC Pending route
      GoRoute(
        path: '/kyc-pending',
        builder: (context, state) => const KycPendingPage(),
      ),
      
      // User details route
      GoRoute(
        path: '/user-details',
        builder: (context, state) => const UserDetailsPage(),
      ),
      
      // Admin login route
      GoRoute(
        path: '/admin-login',
        builder: (context, state) => const AdminLoginPage(),
      ),
      
      // Main app routes
      GoRoute(
        path: '/home',
        builder: (context, state) => const ResponsiveLayout(
          mobileLayout: MobileLayout(),
          desktopLayout: DesktopLayout(),
        ),
      ),
      
      // Account route
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
      ),
      
      // Watchlist route
      GoRoute(
        path: '/watchlist',
        builder: (context, state) => const WatchlistPage(),
      ),
      
      // Charts route
      GoRoute(
        path: '/charts',
        builder: (context, state) => const ChartsPage(),
      ),
      
      // Trade route
      GoRoute(
        path: '/trade',
        builder: (context, state) => const TradePage(),
      ),
      
      // History route
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
      
      // Transactions route
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionsPage(),
      ),
      // Transaction Success route
      GoRoute(
        path: '/transaction_success',
        builder: (context, state) => const TransactionSuccessPage(),
      ),
      // Admin routes
      ShellRoute(
        builder: (context, state, child) => AdminLayout(child: child),
        routes: [
          GoRoute(
            path: '/admin/verify-payments',
            builder: (context, state) => const PaymentVerificationPage(),
          ),

        ],
      ),
      
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}); 