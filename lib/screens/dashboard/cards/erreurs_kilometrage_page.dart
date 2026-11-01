import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../controllers/dashboard_controller.dart';
import 'card_detail_base_page.dart';
import 'navigation_fiches.dart';

class ErreursKilometragePage extends StatelessWidget {
  const ErreursKilometragePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Obx(() {
      return CardDetailBasePage(
        title: 'Erreurs de kilométrage',
        subtitle: '',
        icon: LucideIcons.gauge,
        accentColor: const Color(0xFFDC2626),
        items: controller.erreursKmList,
        onRefresh: () => controller.fetchDashboardData(showLoading: false),
        onItemTap: ouvrirFicheVidange,
        headerPills: [
          _buildPill(
            '${controller.erreursKmCount.value} véhicules',
            controller.erreursKmCount.value > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF1F3A5F),
          ),
        ],
      );
    });
  }

  Widget _buildPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
