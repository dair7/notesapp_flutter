import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Le damos a la app un segundo para respirar y mostrar el logo
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Verificamos el token silenciosamente
    await ref.read(authProvider.notifier).checkAuthStatus();
    
    if (!mounted) return;

    // Si después de verificar hay un usuario logueado, vamos al Dashboard
    if (ref.read(authProvider).isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // Si no, vamos al Login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/Logo.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFF2A9D8F)),
          ],
        ),
      ),
    );
  }
}
