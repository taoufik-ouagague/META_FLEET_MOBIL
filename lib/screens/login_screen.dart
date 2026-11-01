import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/auth_controller.dart';
import '../services/api_service.dart';
import '../widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  AnimationController? _fadeController;
  AnimationController? _scaleController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;

  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController!, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController!, curve: Curves.easeOutBack),
    );

    _fadeController?.forward();
    _scaleController?.forward();
  }

  /// Charge les identifiants préalablement enregistrés
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('remember_me') ?? true;
      final savedLogin = prefs.getString('saved_username');
      final savedPassword = prefs.getString('saved_password');

      if (mounted) {
        setState(() {
          _rememberMe = remember;
          if (remember && savedLogin != null && savedLogin.isNotEmpty) {
            _loginCtrl.text = savedLogin;
            if (savedPassword != null) {
              _passwordCtrl.text = savedPassword;
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeController?.dispose();
    _scaleController?.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;

    final login = _loginCtrl.text.trim();
    final pwd = _passwordCtrl.text.trim();

    try {
      final success = await _authController.authenticate(login, pwd);
      if (!mounted) return;

      if (success) {
        // Enregistrer ou supprimer les identifiants selon l'option Se souvenir de moi
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_username', login);
          await prefs.setString('saved_password', pwd);
        } else {
          await prefs.setBool('remember_me', false);
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
        }

        Get.offAllNamed('/home');
      }
    } catch (_) {
      // Les erreurs sont déjà gérées et affichées via snackbar dans AuthController
    }
  }

  void _showServerConfigDialog() {
    final serverUrlCtrl = TextEditingController(text: ApiService.baseUrl);

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.server,
                      color: Color(0xFF1F3A5F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Configuration Serveur',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Entrez l\'URL de base de l\'API backend (Spring Boot) :',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serverUrlCtrl,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'http://192.168.2.242:8080',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _presetUrlChip(
                    'Localhost',
                    'http://localhost:8080',
                    serverUrlCtrl,
                  ),
                  _presetUrlChip(
                    'Émulateur Android',
                    'http://10.0.2.2:8080',
                    serverUrlCtrl,
                  ),
                  _presetUrlChip(
                    'LAN Prod',
                    'http://192.168.2.242:9797/GMAOAPIPROD',
                    serverUrlCtrl,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F3A5F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final newUrl = serverUrlCtrl.text.trim();
                      if (newUrl.isNotEmpty) {
                        _authController.updateServerUrl(newUrl);
                        Get.back();
                      }
                    },
                    child: Text(
                      'Enregistrer',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetUrlChip(String label, String url, TextEditingController ctrl) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 11)),
      onPressed: () => ctrl.text = url,
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dégradé de fond subtil et lumineux
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEBF3FA), // Bleu glacier très doux
                  Color(0xFFF8FAFC), // Blanc ardoise épuré
                  Color(0xFFF0F6FB), // Nuance brand subtile
                  Color(0xFFE8F2FA), // Base bleutée douce
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),

          // 2. Filigrane subtil de l'atelier de flotte (1.png) avec fondu progressif
          Positioned.fill(
            child: Opacity(
              opacity: 0.14,
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.black, Colors.transparent],
                    stops: [0.0, 0.45, 0.88],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Image.asset('assets/img/1.png', fit: BoxFit.cover),
              ),
            ),
          ),

          // 3. Orbes lumineux ambiants (Mesh Gradient / Effet Aurora)
          // Orbe Cyan / Bleu ciel lumineux (Haut-Droit)
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00C6FF).withValues(alpha: 0.22),
                    const Color(0xFF00C6FF).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Orbe Bleu Marine profond (Haut-Gauche)
          Positioned(
            top: -40,
            left: -50,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1F3A5F).withValues(alpha: 0.14),
                    const Color(0xFF1F3A5F).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.50, 1.0],
                ),
              ),
            ),
          ),

          // Orbe Cyan / Bleu central derrière la carte (magnifie le verre dépoli)
          Positioned(
            top: size.height * 0.38,
            left: size.width * 0.10,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00C6FF).withValues(alpha: 0.15),
                    const Color(0xFF38BDF8).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Orbe Bleu Océan (Bas-Gauche)
          Positioned(
            bottom: -80,
            left: -40,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0284C7).withValues(alpha: 0.16),
                    const Color(0xFF38BDF8).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.50, 1.0],
                ),
              ),
            ),
          ),

          // Orbe Cyan d'accentuation (Centre-Droit)
          Positioned(
            top: size.height * 0.45,
            right: -40,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00C6FF).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.70],
                ),
              ),
            ),
          ),

          // 4. Motifs géométriques télématiques & grille de points (CustomPainter)
          Positioned.fill(child: CustomPaint(painter: _LoginBgDecorPainter())),

          // 5. Contenu du formulaire au premier plan
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ScaleTransition(
                  scale: _scaleAnimation ?? const AlwaysStoppedAnimation(1.0),
                  child: FadeTransition(
                    opacity:
                        _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo & Titre
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onLongPress: _showServerConfigDialog,
                                  child: SizedBox(
                                    width: 86,
                                    height: 72,
                                    child: Image.asset(
                                      'assets/img/logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFF1F3A5F),
                                          Color(0xFF00C6FF),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ).createShader(bounds),
                                  child: Text(
                                    'META FLEET',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Gestion de Parc & GMAO',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Carte du formulaire de connexion en Glassmorphism
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF1F3A5F,
                                  ).withValues(alpha: 0.10),
                                  blurRadius: 36,
                                  offset: const Offset(0, 14),
                                  spreadRadius: -2,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF00C6FF,
                                  ).withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 6),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.72),
                                        Colors.white.withValues(alpha: 0.45),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Connexion',
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Accédez à votre espace flotte et GMAO',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 28),

                                      // Champ Utilisateur
                                      AppTextField(
                                        controller: _loginCtrl,
                                        label: 'Identifiant',
                                        hint: 'username',
                                        icon: LucideIcons.user,
                                        fillColor: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        validator: (val) {
                                          if (val == null ||
                                              val.trim().isEmpty) {
                                            return 'Veuillez saisir votre identifiant';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 20),

                                      // Champ Mot de passe
                                      AppTextField(
                                        controller: _passwordCtrl,
                                        label: 'Mot de passe',
                                        hint: '••••••••',
                                        icon: LucideIcons.lock,
                                        obscure: _obscurePassword,
                                        fillColor: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? LucideIcons.eyeOff
                                                : LucideIcons.eye,
                                            color: const Color(0xFF94A3B8),
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                        validator: (val) {
                                          if (val == null ||
                                              val.trim().isEmpty) {
                                            return 'Veuillez saisir votre mot de passe';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      // Option Se souvenir de moi
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              activeColor: const Color(
                                                0xFF1F3A5F,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFF94A3B8),
                                                width: 1.5,
                                              ),
                                              onChanged: (val) {
                                                setState(() {
                                                  _rememberMe = val ?? false;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _rememberMe = !_rememberMe;
                                              });
                                            },
                                            child: Text(
                                              'Se souvenir de moi',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: const Color(0xFF475569),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 24),

                                      // Bouton Se connecter
                                      Obx(() {
                                        final isLoading =
                                            _authController.isLoading.value;
                                        return SizedBox(
                                          width: double.infinity,
                                          height: 52,
                                          child: ElevatedButton(
                                            onPressed: isLoading
                                                ? null
                                                : _onLoginPressed,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF1F3A5F,
                                              ),
                                              foregroundColor: Colors.white,
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              shadowColor: const Color(
                                                0xFF1F3A5F,
                                              ).withValues(alpha: 0.3),
                                            ),
                                            child: isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.4,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Se connecter',
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Icon(
                                                        LucideIcons.arrowRight,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Copyright
                          Center(
                            child: Text.rich(
                              TextSpan(
                                text: '© 2026 Copyright par ',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'META FLEET',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1F3A5F),
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Peintre personnalisé pour ajouter des motifs télématiques et de connectivité subtils
class _LoginBgDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Anneaux télématiques / radar concentriques centrés autour du logo
    final center = Offset(size.width * 0.5, size.height * 0.16);
    final ringPaint = Paint()
      ..color = const Color(0xFF00C6FF).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 90, ringPaint);
    canvas.drawCircle(center, 150, ringPaint);
    canvas.drawCircle(center, 220, ringPaint);

    // 2. Grille de points subtile en haut à gauche
    final dotPaint = Paint()
      ..color = const Color(0xFF1F3A5F).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 16.0;
    const startX = 24.0;
    const startY = 48.0;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        canvas.drawCircle(
          Offset(startX + c * spacing, startY + r * spacing),
          1.5,
          dotPaint,
        );
      }
    }

    // 3. Grille de points subtile en bas à droite
    final brDotPaint = Paint()
      ..color = const Color(0xFF00C6FF).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final brStartX = size.width - 80;
    final brStartY = size.height * 0.84;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        canvas.drawCircle(
          Offset(brStartX + c * spacing, brStartY + r * spacing),
          1.5,
          brDotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
