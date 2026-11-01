import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../controllers/dashboard_controller.dart';
import 'card_detail_base_page.dart';
import 'navigation_fiches.dart';

class OrNonCloturesPage extends StatelessWidget {
  const OrNonCloturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Obx(() {
      return CardDetailBasePage(
        title: 'OR non clôturés',
        subtitle: '',
        icon: LucideIcons.wrench,
        accentColor: const Color(0xFF8B5CF6),
        items: controller.orNonCloturesList,
        onRefresh: () => controller.fetchDashboardData(showLoading: false),
        onItemTap: ouvrirFicheOr,
        selecteur: CardSelecteur.naturesAnomalies(),
        headerPills: [
          _buildPill(
            '${controller.orNonCloturesCount.value} ordres',
            const Color(0xFF8B5CF6),
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
