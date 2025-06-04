// lib/widgets/compact_route_widget.dart - OVERFLOW PROTECTED
import 'package:flutter/material.dart';
import 'package:camping_osm_navi/models/search_types.dart';

class CompactRouteWidget extends StatelessWidget {
  final String destinationName;
  final double? remainingDistance;
  final double? totalDistance;
  final int? remainingTime;
  final int? totalTime;
  final VoidCallback onEditPressed;
  final VoidCallback onClosePressed;
  final bool isNavigating;

  const CompactRouteWidget({
    super.key,
    required this.destinationName,
    this.remainingDistance,
    this.totalDistance,
    this.remainingTime,
    this.totalTime,
    required this.onEditPressed,
    required this.onClosePressed,
    this.isNavigating = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayDistance = remainingDistance ?? totalDistance;
    final displayTime = remainingTime ?? totalTime;
    final isRemainingInfo = remainingDistance != null && remainingTime != null;
    final isSmallScreen = SmartphoneBreakpoints.isSmallScreen(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 6 : 8,
      ),
      constraints: BoxConstraints(
        // ✅ KRITISCH: Maximale Höhe definieren um Overflow zu verhindern
        maxHeight: isSmallScreen ? 60 : 75,
        minHeight: isSmallScreen ? 50 : 60,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 24.0 : 28.0),
        border: Border.all(
          color: isNavigating
              ? Colors.blue.withAlpha(100)
              : Colors.grey.withAlpha(80),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.08 * 255).round()),
            spreadRadius: 0,
            blurRadius: isSmallScreen ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16.0 : 20.0,
          vertical: isSmallScreen ? 8.0 : 12.0,
        ),
        child: Row(
          children: [
            // Route Status Indicator
            _buildRouteIndicator(context, isSmallScreen),

            SizedBox(width: isSmallScreen ? 12 : 16),

            // Route Information - ✅ FLEX für Overflow-Schutz
            Expanded(
              child: _buildRouteInfo(context, displayDistance, displayTime,
                  isRemainingInfo, isSmallScreen),
            ),

            SizedBox(width: isSmallScreen ? 8 : 12),

            // Action Buttons
            _buildActionButtons(context, isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteIndicator(BuildContext context, bool isSmallScreen) {
    final size = isSmallScreen ? 8.0 : 10.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isNavigating ? Colors.blue : Colors.green,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isNavigating ? Colors.blue : Colors.green).withAlpha(80),
            spreadRadius: isSmallScreen ? 1 : 2,
            blurRadius: isSmallScreen ? 3 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo(BuildContext context, double? distance, int? time,
      bool isRemainingInfo, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // ✅ KRITISCH: Minimale Größe
      children: [
        // Destination Name - ✅ OVERFLOW PROTECTION
        Flexible(
          child: Text(
            destinationName.isNotEmpty ? destinationName : 'Active Route',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1a1a1a),
              height: 1.1, // ✅ Kompaktere Zeilenhöhe
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Time and Distance - ✅ KOMPAKTER
        if (distance != null && time != null) ...[
          SizedBox(height: isSmallScreen ? 2 : 3),
          Flexible(
            child: Row(
              children: [
                // Time
                Flexible(
                  child: Text(
                    '${isRemainingInfo ? "Rest: " : ""}$time min',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 13,
                      fontWeight: FontWeight.w500,
                      color: isNavigating
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Separator
                if (!isSmallScreen) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 2,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),

                  // Distance
                  Flexible(
                    child: Text(
                      _formatDistance(distance),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // Navigation Icon
                if (isNavigating) ...[
                  SizedBox(width: isSmallScreen ? 4 : 6),
                  Icon(
                    Icons.navigation,
                    size: isSmallScreen ? 12 : 14,
                    color: Colors.blue.shade600,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isSmallScreen) {
    final buttonSize = isSmallScreen ? 28.0 : 32.0;
    final iconSize = isSmallScreen ? 14.0 : 16.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit Button
        _buildGoogleStyleButton(
          icon: Icons.edit,
          tooltip: 'Edit route',
          onPressed: onEditPressed,
          isPrimary: false,
          size: buttonSize,
          iconSize: iconSize,
        ),

        SizedBox(width: isSmallScreen ? 4 : 6),

        // Close Button
        _buildGoogleStyleButton(
          icon: Icons.close,
          tooltip: 'End route',
          onPressed: onClosePressed,
          isPrimary: false,
          size: buttonSize,
          iconSize: iconSize,
        ),
      ],
    );
  }

  Widget _buildGoogleStyleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isPrimary,
    required double size,
    required double iconSize,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isPrimary
                ? Colors.blue.withAlpha(20)
                : Colors.grey.withAlpha(15),
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(
              color: isPrimary
                  ? Colors.blue.withAlpha(40)
                  : Colors.grey.withAlpha(30),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: isPrimary ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return "${distanceInMeters.round()}m";
    } else {
      final km = distanceInMeters / 1000;
      if (km < 10) {
        return "${km.toStringAsFixed(1)}km";
      } else {
        return "${km.round()}km";
      }
    }
  }
}

// Route Progress Indicator Widget - ✅ OVERFLOW PROTECTED
class RouteProgressIndicator extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double height;

  const RouteProgressIndicator({
    super.key,
    required this.progress,
    this.color = Colors.blue,
    this.height = 4.0,
  });

  @override
  State<RouteProgressIndicator> createState() => _RouteProgressIndicatorState();
}

class _RouteProgressIndicatorState extends State<RouteProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: PremiumCurves.resize, // ✅ Overflow-sichere Curve
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(RouteProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: PremiumCurves.resize,
      ));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      constraints: const BoxConstraints(
        minWidth: 50, // ✅ Minimum Width
        maxWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        color: widget.color.withAlpha(30),
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _animation.value.clamp(0.0, 1.0), // ✅ Clamped
            child: Container(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withAlpha(60),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
