import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AutoCarousel extends StatefulWidget {
  final List<String> imagePaths;
  final Duration autoPlayInterval;
  final double height;
  final bool isZoomable;
  final String category;

  const AutoCarousel({
    super.key,
    required this.imagePaths,
    this.autoPlayInterval = const Duration(milliseconds: 3500),
    required this.height,
    this.isZoomable = false,
    required this.category,
  });

  @override
  State<AutoCarousel> createState() => _AutoCarouselState();
}

class _AutoCarouselState extends State<AutoCarousel> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  bool _isPaused = false;
  Timer? _resumeTimer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resumeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.imagePaths.length <= 1) return;
    _timer = Timer.periodic(widget.autoPlayInterval, (timer) {
      if (_isPaused || !_isVisible) return;

      final nextPage = (_currentPage + 1) % widget.imagePaths.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _pauseTimerForUserInteraction() {
    setState(() {
      _isPaused = true;
    });
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isPaused = false;
        });
      }
    });
  }

  IconData get _categoryIcon {
    switch (widget.category) {
      case 'Leche':
        return Icons.local_drink_rounded;
      case 'Queso':
        return Icons.inventory_2_rounded;
      case 'Insumos':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  Widget _buildFallbackImage() {
    return Container(
      color: AppColors.greenSurface,
      alignment: Alignment.center,
      child: Icon(_categoryIcon, size: 54, color: AppColors.primaryGreenDark),
    );
  }

  Widget _buildImage(String path) {
    ImageProvider provider;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      provider = NetworkImage(path);
    } else if (path.startsWith('assets/')) {
      provider = AssetImage(path);
    } else {
      provider = FileImage(File(path));
    }

    return Container(
      color: const Color(0xFFF2F5EF),
      alignment: Alignment.center,
      child: Image(
        image: provider,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackImage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _buildFallbackImage(),
      );
    }

    final totalImages = widget.imagePaths.length;

    Widget carouselBody = NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is UserScrollNotification) {
          if (notification.direction != ScrollDirection.idle) {
            _pauseTimerForUserInteraction();
          }
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: totalImages,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final path = widget.imagePaths[index];
          if (widget.isZoomable) {
            return _ZoomableImage(imageBuilder: () => _buildImage(path));
          }
          return _buildImage(path);
        },
      ),
    );

    // Apply visibility detection
    carouselBody = VisibilityDetector(
      key: Key('carousel_${widget.hashCode}'),
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction > 0.1;
        if (_isVisible != isVisible) {
          setState(() {
            _isVisible = isVisible;
          });
        }
      },
      child: carouselBody,
    );

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(child: carouselBody),
          // Dots indicator
          if (totalImages > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalImages,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 10 : 6,
                    height: _currentPage == index ? 10 : 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primaryGreen
                          : Colors.white.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          // Page counter for details
          if (widget.isZoomable && totalImages > 1)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPage + 1}/$totalImages',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final Widget Function() imageBuilder;
  const _ZoomableImage({required this.imageBuilder});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        clipBehavior: Clip.none,
        child: widget.imageBuilder(),
      ),
    );
  }
}
