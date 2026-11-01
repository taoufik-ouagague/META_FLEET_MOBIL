import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'ambient_background.dart';
import 'page_entrance_animation.dart';

/// Briques communes aux pages « aperçu » (OR, véhicule, vidange) : coquille à
/// onglets, cartes en verre et lignes d'information. Extrait de la fiche OR
/// pour que les trois écrans partagent exactement le même rendu.

// Palette des lignes : une couleur par famille de donnée.
const kApBleu = Color(0xFF2563EB);
const kApViolet = Color(0xFF7C3AED);
const kApCyan = Color(0xFF0891B2);
const kApVert = Color(0xFF059669);
const kApAmbre = Color(0xFFD97706);
const kApRouge = Color(0xFFDC2626);
const kApArdoise = Color(0xFF64748B);

const double kApHauteurOnglets = 48;

/// Coquille commune : en-tête dégradé, onglets, fond ambiant.
class ApercuScaffold extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final List<String> onglets;
  final List<Widget> contenus;
  final bool chargement;

  /// Onglet ouvert a l'arrivee, pour les acces directs depuis le tableau de bord.
  final int ongletInitial;

  const ApercuScaffold({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.onglets,
    required this.contenus,
    this.chargement = false,
    this.ongletInitial = 0,
  });

  @override
  Widget build(BuildContext context) {
    // La barre flotte au-dessus du fond : le contenu des onglets est décalé
    // d'autant, sinon il passerait dessous.
    final hauteurBarre =
        MediaQuery.of(context).padding.top + kToolbarHeight + kApHauteurOnglets;

    return DefaultTabController(
      length: onglets.length,
      initialIndex: ongletInitial.clamp(0, onglets.length - 1),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F3A5F), Color(0xFF2563EB)],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
            color: Colors.white,
            onPressed: () => Get.back(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                sousTitre,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kApHauteurOnglets),
            child: Column(
              children: [
                // Hauteur réservée en permanence : sinon l'apparition de la
                // barre de chargement fait déborder le PreferredSize de 2 px.
                SizedBox(
                  height: 2,
                  child: chargement
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.70),
                  indicatorColor: Colors.white,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: onglets.map((t) => Tab(text: t)).toList(),
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AmbientBackground(),
            Padding(
              padding: EdgeInsets.only(top: hauteurBarre),
              child: TabBarView(children: contenus),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une page du slider : pastille de sélection + contenu.
class ApercuSliderPage {
  final String label;
  final IconData icone;
  final Widget contenu;

  const ApercuSliderPage({
    required this.label,
    required this.icone,
    required this.contenu,
  });
}

/// Slider d'onglet : sélecteur en pastilles en haut, PageView au milieu,
/// points en bas. Sert à regrouper plusieurs cartes dans un même onglet.
class ApercuSlider extends StatefulWidget {
  final List<ApercuSliderPage> pages;

  const ApercuSlider({super.key, required this.pages});

  @override
  State<ApercuSlider> createState() => _ApercuSliderState();
}

class _ApercuSliderState extends State<ApercuSlider> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _allerA(int index) => _controller.animateToPage(
    index,
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeInOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageEntranceAnimation(
          duration: const Duration(milliseconds: 380),
          slideOffset: 18,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _selecteur(),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: PageEntranceAnimation(
            duration: const Duration(milliseconds: 420),
            delay: const Duration(milliseconds: 90),
            slideOffset: 22,
            child: PageView(
              controller: _controller,
              onPageChanged: (index) => setState(() => _page = index),
              children: widget.pages.map((p) => p.contenu).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _points(),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _selecteur() {
    Widget pilule(int index, ApercuSliderPage page) {
      final actif = _page == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => _allerA(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: actif ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: actif
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  page.icone,
                  size: 15,
                  color: actif
                      ? const Color(0xFF1F3A5F)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    page.label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
                      color: actif
                          ? const Color(0xFF1F3A5F)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.90),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.pages.length; i++)
            pilule(i, widget.pages[i]),
        ],
      ),
    );
  }

  Widget _points() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.pages.length,
        (index) => GestureDetector(
          onTap: () => _allerA(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _page == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _page == index ? kApBleu : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Page de slider : la carte se dimensionne sur son contenu au lieu d'etre
/// etiree par le PageView.
Widget apercuPageCartes(List<Widget> cartes) {
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Column(children: cartes),
  );
}

/// Dialogue de confirmation en verre : pastille colorée selon l'action,
/// numéro du bon en sous-titre, commentaire facultatif et bouton d'action
/// repris de la couleur de l'action.
Widget apercuDialogueAction({
  required String titre,
  required String numero,
  required String message,
  required String libelleAction,
  required Color couleur,
  required IconData icone,
  TextEditingController? commentaire,
}) {
  return Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.94),
                Colors.white.withValues(alpha: 0.82),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.5,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: couleur.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: couleur.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(icone, size: 20, color: couleur),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titre,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            numero.isEmpty ? 'Bon' : 'Bon $numero',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: couleur,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    height: 1.35,
                    color: const Color(0xFF64748B),
                  ),
                ),
                if (commentaire != null) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: commentaire,
                    maxLines: 3,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Commentaire (facultatif)',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: const Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.70),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.90),
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: const Color(
                            0xFF1F3A5F,
                          ).withValues(alpha: 0.10),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: couleur, width: 1.5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Get.back(result: false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: couleur.withValues(alpha: 0.30),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Get.back(result: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: couleur,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            libelleAction,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Surface vitrée commune aux cartes : le fond ambiant transparaît au travers.
class ApercuVerre extends StatelessWidget {
  final Widget child;
  final double rayon;

  const ApercuVerre({super.key, required this.child, this.rayon = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rayon),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rayon),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(rayon),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  Colors.white.withValues(alpha: 0.65),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Liste d'onglet avec animation d'entrée échelonnée.
Widget apercuScroll(List<Widget> enfants, {Key? cle}) {
  final visibles = enfants.where((w) => w is! SizedBox).toList();
  if (visibles.isEmpty) return apercuVide('Aucune information');

  return ListView(
    key: cle,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
      for (var i = 0; i < enfants.length; i++)
        PageEntranceAnimation(
          duration: const Duration(milliseconds: 380),
          delay: Duration(milliseconds: (i * 45).clamp(0, 320)),
          slideOffset: 18,
          child: enfants[i],
        ),
    ],
  );
}

Widget apercuVide(String message) {
  return PageEntranceAnimation(
    duration: const Duration(milliseconds: 380),
    slideOffset: 14,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.searchX, size: 32, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Une section disparaît si toutes ses lignes sont vides.
Widget apercuSection(String titre, List<Widget?> lignes, {Widget? action}) {
  final visibles = lignes.whereType<Widget>().toList();
  if (visibles.isEmpty) return const SizedBox.shrink();

  return ApercuVerre(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                titre,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 10),
        ...visibles,
      ],
    ),
  );
}

/// Carte à en-tête coloré (pastille + titre + badge optionnel).
Widget apercuCarte({
  required dynamic titre,
  required IconData icone,
  required Color couleur,
  required List<Widget?> lignes,
  String? etiquette,
  Widget? action,
}) {
  final visibles = lignes.whereType<Widget>().toList();
  final libelle = titre?.toString().trim();
  final badge = etiquette?.trim();

  return ApercuVerre(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icone, size: 14, color: couleur),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (libelle == null || libelle.isEmpty) ? '—' : libelle,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (badge != null && badge.isNotEmpty)
                    Text(
                      badge,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: couleur,
                      ),
                    ),
                ],
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 10),
        if (visibles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Aucun détail',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: const Color(0xFF94A3B8),
              ),
            ),
          )
        else
          ...visibles,
      ],
    ),
  );
}

/// Ligne label / valeur avec pastille d'icône. Renvoie null si la valeur est
/// absente : la ligne est alors masquée.
Widget? apercuLigne(
  String label,
  dynamic value,
  IconData icone,
  Color couleur,
) {
  final texte = value?.toString().trim() ?? '';
  if (texte.isEmpty || texte == 'null') return null;

  return Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icone, size: 12, color: couleur),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              texte,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: couleur,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Tous les endpoints ne passent pas par GlobalConstants.getStatusLibelle :
/// certains renvoient le code brut ("1"). Même table que le backend ; une
/// valeur déjà libellée, ou un code inconnu, ressort inchangée.
const _libellesStatut = {
  '-6': 'Vendu',
  '-5': 'F/Déclaration',
  '-4': 'Rejeté',
  '-3': 'Annulé',
  '-2': 'Archive',
  '-1': 'Supprimé',
  '0': 'Inactif',
  '1': 'Actif',
  '2': 'Planifié',
  '3': 'Validé',
  '4': 'Clôturé',
  '5': 'Réalisé',
  '6': 'Reporté',
  '7': 'En cours',
  '8': 'Monté',
  '9': 'Démonté',
  '10': 'Replanifié',
  '11': 'Au rebut',
  '12': 'Alerte',
  '13': 'Nouveau',
  '15': 'En cours de planification',
  '20': 'Saisie',
  '21': 'Validée',
  '22': 'Diagnostiquée',
  '23': 'Transformée en OT',
  '41': 'Réglé',
};

String apercuLibelleStatut(String statut) =>
    _libellesStatut[statut.trim()] ?? statut;

/// Couleur par statut ; bleu si le libellé est inconnu.
Color apercuCouleurStatut(String statut) {
  final s = statut.toUpperCase();
  if (s.contains('ANNUL') ||
      s.contains('REJET') ||
      s.contains('SUPPRIM') ||
      s.contains('RETARD')) {
    return kApRouge;
  }
  if (s.contains('CLÔTUR') || s.contains('CLOTUR') || s.contains('ARCHIV')) {
    return const Color(0xFF475569);
  }
  if (s.contains('VALID') ||
      s.contains('APPROUV') ||
      s.contains('RÉALIS') ||
      s.contains('REALIS') ||
      s.contains('ACTIF')) {
    return kApVert;
  }
  if (s.contains('COURS') ||
      s.contains('ATTENTE') ||
      s.contains('PLANIFI') ||
      s.contains('INACTIF')) {
    return kApAmbre;
  }
  return kApBleu;
}

/// Même gabarit que [apercuLigne], mais la valeur est une pastille colorée.
Widget? apercuLigneStatut(
  String label,
  dynamic value, {
  bool avecIcone = false,
}) {
  final brut = value?.toString().trim() ?? '';
  if (brut.isEmpty || brut == 'null') return null;

  final texte = apercuLibelleStatut(brut);
  final couleur = apercuCouleurStatut(texte);

  return Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avecIcone) ...[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(LucideIcons.checkCircle2, size: 12, color: couleur),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: couleur.withValues(alpha: 0.30)),
              ),
              child: Text(
                texte,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: couleur,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Formatage ──

String? apercuDate(dynamic raw) {
  final texte = raw?.toString() ?? '';
  if (texte.isEmpty) return null;
  if (texte.length < 10) return texte;
  final parts = texte.substring(0, 10).split('-');
  if (parts.length != 3) return texte.substring(0, 10);
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String? apercuKm(dynamic raw) {
  if (raw == null) return null;
  final texte = raw.toString().trim();
  if (texte.isEmpty) return null;
  final nombre = num.tryParse(texte);
  final valeur = nombre == null ? texte : nombre.toFalseFreeString();
  return '$valeur km';
}

String? apercuMontant(dynamic raw) {
  if (raw is! num) return null;
  return '${raw.toStringAsFixed(2)} MAD';
}

extension on num {
  /// 175000.0 → « 175000 » : les kilométrages arrivent en double.
  String toFalseFreeString() => this % 1 == 0 ? toInt().toString() : toString();
}
