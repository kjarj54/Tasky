import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multi_session_provider.dart';
import '../providers/auth_provider.dart';
import '../models/auth.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class MultiSessionLoginScreen extends StatefulWidget {
  final bool isNewSession;
  
  const MultiSessionLoginScreen({
    super.key,
    this.isNewSession = true,
  });

  @override
  State<MultiSessionLoginScreen> createState() => _MultiSessionLoginScreenState();
}

class _MultiSessionLoginScreenState extends State<MultiSessionLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final loginRequest = LoginRequest(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        final authResponse = await AuthService.login(loginRequest);
        
        if (mounted) {
          final multiSessionProvider = context.read<MultiSessionProvider>();          // Verificar si ya existe una sesión para este usuario
          if (multiSessionProvider.hasSessionForUser(authResponse.user.id)) {
            // Cambiar a la sesión existente
            await multiSessionProvider.createOrSwitchToUserSession(authResponse.user);
            
            if (widget.isNewSession) {
              Navigator.of(context).pop();
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sesión de ${authResponse.user.name} ya estaba activa'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            // Crear nueva sesión con datos de autenticación
            await multiSessionProvider.createSessionWithAuthData(
              authResponse.user,
              authResponse.token,
              authResponse.refreshToken,
            );
            
            if (widget.isNewSession) {
              Navigator.of(context).pop();
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sesión iniciada para ${authResponse.user.name}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isNewSession 
          ? AppBar(
              title: const Text('Agregar nueva sesión'),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo y título
                Icon(
                  Icons.task_alt,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isNewSession ? 'Nueva Sesión' : 'Iniciar Sesión',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isNewSession 
                      ? 'Inicia sesión con otra cuenta'
                      : 'Gestiona tus tareas de manera eficiente',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Campo de email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu correo electrónico';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Por favor ingresa un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo de contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Mostrar error si existe
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Botón de login
                FilledButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Iniciar Sesión'),
                ),
                const SizedBox(height: 16),

                // Botón de registro
                TextButton(
                  onPressed: _isLoading
                      ? null                      : () {
                          // Create a new AuthProvider for registration
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChangeNotifierProvider<AuthProvider>(
                                create: (_) => AuthProvider(),
                                child: const RegisterScreen(),
                              ),
                            ),
                          );
                        },
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),

                // Botón para ver sesiones activas (solo si es nueva sesión)
                if (widget.isNewSession) ...[
                  const SizedBox(height: 16),
                  Consumer<MultiSessionProvider>(
                    builder: (context, multiSessionProvider, _) {
                      if (multiSessionProvider.hasActiveSessions) {
                        return OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.people),
                          label: Text(
                            'Ver ${multiSessionProvider.sessionCount} sesión${multiSessionProvider.sessionCount > 1 ? 'es' : ''} activa${multiSessionProvider.sessionCount > 1 ? 's' : ''}',
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
