import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../controllers/dashboard_controller.dart';
import 'card_detail_base_page.dart';
import 'navigation_fiches.dart';

class ArticlesSansBaPage extends StatelessWidget {
  const ArticlesSansBaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Obx(() {
      return CardDetailBasePage(
        title: 'Articles sans B.A validé',
        subtitle: '',
        icon: LucideIcons.receipt,
        accentColor: const Color(0xFFE11D48),
        items: controller.articlesSansBaList,
        onRefresh: () => controller.fetchDashboardData(showLoading: false),
        onItemTap: (item) => ouvrirFicheOr(item, onglet: OngletOr.ligneDemande),
        headerPills: [
          if (controller.articlesSansBaSansBon.value > 0)
            _buildPill(
              '${controller.articlesSansBaSansBon.value} sans bon',
              const Color(0xFFDC2626),
            ),
          _buildPill(
            '${controller.articlesSansBaTotal.value} articles au total',
            const Color(0xFF1F3A5F),
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
