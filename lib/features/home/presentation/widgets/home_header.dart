import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hamyar_hashtom_plus/core/constants/app_constants.dart';
import 'package:hamyar_hashtom_plus/core/router/app_routes.dart';
import 'package:hamyar_hashtom_plus/core/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      'assets/images/fahmino_app_icon.jpg',
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('فضای یادگیری پایه هشتم',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withAlpha(210),
                            )),
                        Text(AppConstants.appName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            )),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'جست‌وجو',
                    onPressed: () => context.go(AppRoutes.search),
                    icon: const Icon(Icons.search_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const _FahminoCoverArtwork(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('یادگیری رو از همین‌جا شروع کن',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            )),
                        const SizedBox(height: 7),
                        Text('درس بخوان، تمرین کن و پیشرفتت را بسنج.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withAlpha(220),
                              height: 1.5,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SearchBox(onTap: () => context.go(AppRoutes.search)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeaderAction(
                      icon: Icons.menu_book_rounded,
                      label: 'انتخاب درس',
                      onTap: () => context.go(AppRoutes.subjects),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeaderAction(
                      icon: Icons.timer_rounded,
                      label: 'شروع آزمون',
                      onTap: () => context.push(
                        AppRoutes.featureSubjects('quiz'),
                      ),
                      outlined: true,
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
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.white.withAlpha(18) : Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: outlined
                ? Border.all(color: Colors.white.withAlpha(90))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19,
                  color: outlined ? Colors.white : AppColors.primary),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    color: outlined ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'جست‌وجو در درس‌ها، جزوه‌ها و سؤال‌ها',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}


class _FahminoCoverArtwork extends StatelessWidget {
  const _FahminoCoverArtwork();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'کاور گرافیکی فهمینو؛ کتاب باز و ستاره‌های یادگیری',
      image: true,
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.white.withAlpha(58),
                    Colors.white.withAlpha(12),
                  ],
                ),
                border: Border.all(color: Colors.white.withAlpha(72)),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 21,
                color: Colors.white.withAlpha(230),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 9,
              child: Icon(
                Icons.star_rounded,
                size: 18,
                color: Colors.amber.shade200,
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: -0.10,
                child: Container(
                  width: 70,
                  height: 82,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEFC),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(65),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                        size: 39,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'VIII',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 1,
              right: 4,
              child: Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: const Color(0xFFB8F3E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDark, width: 2),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 17,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
