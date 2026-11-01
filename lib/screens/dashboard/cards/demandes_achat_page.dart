import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../controllers/dashboard_controller.dart';
import 'card_detail_base_page.dart';
import 'navigation_fiches.dart';

class DemandesAchatPage extends StatelessWidget {
  const DemandesAchatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Obx(() {
      return CardDetailBasePage(
        title: 'Demandes d\'achat',
        subtitle: '',
        icon: LucideIcons.shoppingCart,
        accentColor: const Color(0xFF0EA5E9),
        items: controller.demandesAchatList,
        onRefresh: () => controller.fetchDashboardData(showLoading: false),
        onItemTap: (item) =>
            ouvrirFicheOr(item, onglet: OngletOr.approvisionnement),
        headerPills: [
          _buildPill(
            '${controller.demandesAchatCount.value} bons en cours',
            const Color(0xFF0EA5E9),
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
