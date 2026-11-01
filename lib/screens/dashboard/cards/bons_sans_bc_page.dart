import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../controllers/dashboard_controller.dart';
import 'card_detail_base_page.dart';
import 'navigation_fiches.dart';

class BonsSansBcPage extends StatelessWidget {
  const BonsSansBcPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Obx(() {
      return CardDetailBasePage(
        title: 'Bons validés sans B.C',
        subtitle: '',
        icon: LucideIcons.fileCheck,
        accentColor: const Color(0xFFF97316),
        items: controller.bonsSansBcList,
        onRefresh: () => controller.fetchDashboardData(showLoading: false),
        onItemTap: (item) =>
            ouvrirFicheOr(item, onglet: OngletOr.receptionFinanciere),
        headerPills: [
          _buildPill(
            '${controller.bonsSansBcCount.value} bons sans B.C',
            const Color(0xFFF97316),
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
