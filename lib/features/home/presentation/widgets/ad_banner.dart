import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/admin/data/repositories/system_config_repository.dart';

class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  List<String> _ads = [
    "🎉 Premium discounts available now!",
    "🔥 Hot matches near you!",
    "💎 Verify your profile for free badge",
    "🚀 Boost your profile to get more views",
  ];
  String _bannerImage = 'https://images.unsplash.com/photo-1474044158699-59270e99d211';

  @override
  void initState() {
    super.initState();
    _loadDynamicContent();
    _startAutoScroll();
  }

  Future<void> _loadDynamicContent() async {
    try {
      final repo = ref.read(systemConfigRepositoryProvider);
      final results = await Future.wait([
        repo.fetchBannerAds(),
        repo.fetchBannerImage(),
      ]);

      final dynamicAds = results[0] as List<String>;
      final dynamicImage = results[1] as String;

      if (mounted) {
        setState(() {
          if (dynamicAds.isNotEmpty) {
            _ads = dynamicAds;
            if (_currentPage >= _ads.length) {
              _currentPage = 0;
              _pageController.jumpToPage(0);
            }
          }
          _bannerImage = dynamicImage;
        });
      }
    } catch (e) {
      // Keep defaults
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_pageController.hasClients) return;
      
      if (_currentPage < _ads.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building AdBanner with Image: $_bannerImage');
    return Container(
      height: 120,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image with Error Handling
            Positioned.fill(
              child: Image.network(
                _bannerImage,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('AdBanner Image Error: $error');
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Dark Overlay for Text Readability
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
            // Scrolling Text Content
            PageView.builder(
              controller: _pageController,
              itemCount: _ads.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _ads[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
