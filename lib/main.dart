import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'controllers/agenda_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/demande_or_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/journal_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/or_controller.dart';
import 'controllers/pneumatique_controller.dart';
import 'controllers/vehicule_controller.dart';
import 'controllers/vidange_controller.dart';
import 'screens/home/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  await AppChannel.instance.init();

  runApp(const MetaFleetApp());
}

class MetaFleetApp extends StatelessWidget {
  const MetaFleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialisation permanente des contrôleurs métier
    Get.put(AuthController(), permanent: true);
    Get.put(VehiculeController(), permanent: true);
    Get.put(DashboardController(), permanent: true);
    Get.put(OrController(), permanent: true);
    Get.put(VidangeController(), permanent: true);
    Get.put(AgendaController(), permanent: true);
    Get.put(DemandeOrController(), permanent: true);
    Get.put(PneumatiqueController(), permanent: true);
    Get.put(JournalController(), permanent: true);
    Get.put(ChatController(), permanent: true);
    Get.put(NotificationController(), permanent: true);

    return GetMaterialApp(
      title: 'Meta Fleet',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F3A5F),
          primary: const Color(0xFF1F3A5F),
          secondary: const Color(0xFFE81E2A),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1F3A5F)),
        ),
      ),
      initialRoute: '/splash',
      getPages: [
        GetPage(
          name: '/splash',
          page: () => const SplashScreen(),
          transition: Transition.fade,
        ),
        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/home',
          page: () => const HomeScreen(),
          transition: Transition.fadeIn,
        ),
      ],
    );
  }
}
