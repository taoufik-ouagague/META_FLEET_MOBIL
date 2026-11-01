import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../controllers/dashboard_controller.dart';
import 'card_detail_base_page.dart';

class OperationsRetardPage extends StatelessWidget {
  const OperationsRetardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Obx(() {
      return CardDetailBasePage(
        title: 'Opérations en retard',
        subtitle: '',
        icon: LucideIcons.clock,
        accentColor: const Color(0xFF0891B2),
        items: controller.operationsEnRetardList,
        onRefresh: () => controller.fetchDashboardData(showLoading: false),
        headerPills: [
          _buildPill(
            '${controller.operationsEnRetardCount.value} opérations',
            controller.operationsEnRetardCount.value > 0
                ? const Color(0xFF0891B2)
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
