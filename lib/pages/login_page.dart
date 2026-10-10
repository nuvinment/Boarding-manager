import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

/// Unified login page.
/// - Staff / Manager / Super-Admin:  email + PIN pad
/// - Boarder:                        email + password (text field)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Toggle between "Staff" and "Boarder" login modes
  bool _isBoarderMode = false;

  // Shared
  final _emailCtrl = TextEditingController();

  // Boarder mode
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Staff/Manager PIN mode
  String _pinInput = '';
  static const _pinLength = 6;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Login logic
  // -----------------------------------------------------------------------

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      if (_isBoarderMode) {
        if (_passwordCtrl.text.isEmpty) {
          setState(() { _isLoading = false; _errorMessage = 'Please enter your password.'; });
          return;
        }
        await AuthService.instance.loginBoarder(
          email: email,
          password: _passwordCtrl.text,
        );
      } else {
        if (_pinInput.length < _pinLength) {
          setState(() { _isLoading = false; _errorMessage = 'Please enter your full $_pinLength-digit PIN.'; });
          return;
        }
        await AuthService.instance.loginWithPin(email: email, pin: _pinInput);
      }

      if (!mounted) return;
      // Navigate to root — AppRouter rebuilds based on role
      Navigator.of(context).pushReplacementNamed('/');
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _errorMessage = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  // -----------------------------------------------------------------------
  // PIN pad helpers
  // -----------------------------------------------------------------------

  void _onPinKey(String key) {
    if (key == '⌫') {
      if (_pinInput.isNotEmpty) setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
    } else if (_pinInput.length < _pinLength) {
      setState(() => _pinInput += key);
    }
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Logo / Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 44),
              ),

              const SizedBox(height: 24),

              Text(
                'Boarding Manager',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _isBoarderMode ? 'Sign in as Boarder' : 'Staff / Manager Login',
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),

              const SizedBox(height: 32),

              // Mode toggle
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Staff / Manager'), icon: Icon(Icons.admin_panel_settings)),
                  ButtonSegment(value: true,  label: Text('Boarder'),         icon: Icon(Icons.person)),
                ],
                selected: {_isBoarderMode},
                onSelectionChanged: (s) => setState(() {
                  _isBoarderMode = s.first;
                  _pinInput      = '';
                  _errorMessage  = null;
                }),
              ),

              const SizedBox(height: 28),

              // Email field
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: _isBoarderMode ? TextInputAction.next : TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) { if (_errorMessage != null) setState(() => _errorMessage = null); },
              ),

              const SizedBox(height: 16),

              // ── Boarder: password field ──────────────────────────────
              if (_isBoarderMode) ...[
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Staff/Manager: PIN pad ────────────────────────────────
              if (!_isBoarderMode) ...[
                const SizedBox(height: 4),
                Text('Enter your $_pinLength-digit PIN',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 12),
                _PinDots(pinLength: _pinLength, filled: _pinInput.length),
                const SizedBox(height: 16),
                _PinPad(onKey: _onPinKey),
                const SizedBox(height: 20),
              ],

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.onErrorContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Login button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _login,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              // Boarder register link
              if (_isBoarderMode) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?", style: TextStyle(color: colors.onSurfaceVariant)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/signup'),
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              // Default credentials hint (remove in production)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Text('Default admin credentials:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Email: admin@boarding.local\nPIN: 123456',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: colors.onPrimaryContainer)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIN dot indicators
// ---------------------------------------------------------------------------

class _PinDots extends StatelessWidget {
  final int pinLength;
  final int filled;

  const _PinDots({required this.pinLength, required this.filled});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pinLength, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? color : Colors.transparent,
            border: Border.all(color: isFilled ? color : Colors.grey.shade400, width: 2),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// PIN numpad
// ---------------------------------------------------------------------------

class _PinPad extends StatelessWidget {
  final void Function(String) onKey;

  const _PinPad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['','0','⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80, height: 64);
            return _PinKey(label: key, onTap: () => onKey(key));
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _PinKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PinKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDelete = label == '⌫';
    final colors   = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: isDelete ? colors.errorContainer.withValues(alpha: 0.6) : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 60,
            child: Center(
              child: isDelete
                  ? Icon(Icons.backspace_outlined, color: colors.error, size: 22)
                  : Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.onSurface)),
            ),
          ),
        ),
      ),
    );
  }
}
