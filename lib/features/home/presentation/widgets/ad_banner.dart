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
  final PageController _textPageController = PageController();
  final PageController _imagePageController = PageController();
  int _currentTextPage = 0;
  int _currentImagePage = 0;
  Timer? _textTimer;
  Timer? _imageTimer;

  List<String> _ads = [
    "🎉 Premium discounts available now!",
    "🔥 Hot matches near you!",
    "💎 Verify your profile for free badge",
    "🚀 Boost your profile to get more views",
  ];
  
  List<String> _bannerImages = [
    'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80'
  ];

  @override
  void initState() {
    super.initState();
    _loadDynamicContent();
    _startTimers();
  }

  Future<void> _loadDynamicContent() async {
    try {
      final repo = ref.read(systemConfigRepositoryProvider);
      final results = await Future.wait([
        repo.fetchBannerAds(),
        repo.fetchBannerImages(),
      ]);

      final dynamicAds = results[0] as List<String>;
      final dynamicImages = results[1] as List<String>;

      if (mounted) {
        setState(() {
          if (dynamicAds.isNotEmpty) {
            _ads = dynamicAds;
            if (_currentTextPage >= _ads.length) {
              _currentTextPage = 0;
              _textPageController.jumpToPage(0);
            }
          }
          if (dynamicImages.isNotEmpty) {
            _bannerImages = dynamicImages;
            if (_currentImagePage >= _bannerImages.length) {
              _currentImagePage = 0;
              _imagePageController.jumpToPage(0);
            }
          }
        });
      }
    } catch (e) {
      // Keep defaults
    }
  }

  void _startTimers() {
    // Text Auto Scroll
    _textTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_textPageController.hasClients) return;
      
      if (_currentTextPage < _ads.length - 1) {
        _currentTextPage++;
      } else {
        _currentTextPage = 0;
      }

      _textPageController.animateToPage(
        _currentTextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });

    // Image Auto Scroll (slower)
    _imageTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_imagePageController.hasClients || _bannerImages.length <= 1) return;
      
      if (_currentImagePage < _bannerImages.length - 1) {
        _currentImagePage++;
      } else {
        _currentImagePage = 0;
      }

      _imagePageController.animateToPage(
        _currentImagePage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _imageTimer?.cancel();
    _textPageController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            // Background Image Carousel
            Positioned.fill(
              child: PageView.builder(
                controller: _imagePageController,
                itemCount: _bannerImages.length,
                onPageChanged: (index) {
                  setState(() => _currentImagePage = index);
                },
                itemBuilder: (context, index) {
                  return Image.network(
                    _bannerImages[index],
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
              controller: _textPageController,
              itemCount: _ads.length,
              onPageChanged: (index) {
                setState(() {
                  _currentTextPage = index;
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
