import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../controllers/dashboard_controller.dart';
import 'card_detail_base_page.dart';
import 'navigation_fiches.dart';

class AlertesVidangePage extends StatelessWidget {
  const AlertesVidangePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Obx(() {
      // Les trois pastilles filtrent la liste : depasses (act <= 0),
      // imminentes (0 < act <= 500) et toutes les alertes.
      return CardDetailBasePage(
        title: 'Alertes vidange',
        subtitle: '',
        icon: LucideIcons.alertTriangle,
        accentColor: const Color(0xFFF59E0B),
        items: controller.alertesVidangeList,
        onRefresh: () => controller.fetchDashboardData(showLoading: false),
        onItemTap: ouvrirFicheVidange,
        filtres: [
          CardFiltre(
            label: '${controller.alertesVidangeDepasses.value} dépassés',
            couleur: const Color(0xFFEF4444),
            predicat: (item) {
              final act = item['act'];
              return act is num && act <= 0;
            },
          ),
          CardFiltre(
            label: '${controller.alertesVidangeImminents.value} imminentes',
            couleur: const Color(0xFFF59E0B),
            predicat: (item) {
              final act = item['act'];
              return act is num && act > 0 && act <= 500;
            },
          ),
          CardFiltre(
            label: '${controller.alertesVidangeCount.value} alertes',
            couleur: const Color(0xFF1F3A5F),
          ),
        ],
      );
    });
  }
}
