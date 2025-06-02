// lib/widgets/compact_route_widget.dart - COMPLETE FILE
import 'package:flutter/material.dart';

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

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.0),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        child: Row(
          children: [
            // Route Status Indicator
            _buildRouteIndicator(context),

            const SizedBox(width: 16),

            // Route Information
            Expanded(
              child: _buildRouteInfo(context, displayDistance, displayTime, isRemainingInfo),
            ),

            const SizedBox(width: 12),

            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteIndicator(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: isNavigating ? Colors.blue : Colors.green,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isNavigating ? Colors.blue : Colors.green).withAlpha(80),
            spreadRadius: 2,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo(BuildContext context, double? distance, int? time, bool isRemainingInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Destination Name
        Text(
          destinationName.isNotEmpty ? destinationName : 'Active Route',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1a1a1a),
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 3),

        // Time and Distance
        if (distance != null && time != null)
          Row(
            children: [
              // Time
              Text(
                '${isRemainingInfo ? "Remaining: " : ""}$time min',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isNavigating ? Colors.blue.shade700 : Colors.grey.shade700,
                ),
              ),

              // Separator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),

              // Distance
              Text(
                _formatDistance(distance),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),

              // Navigation Icon
              if (isNavigating) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.navigation,
                  size: 14,
                  color: Colors.blue.shade600,
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit Button
        _buildGoogleStyleButton(
          icon: Icons.edit,
          tooltip: 'Edit route',
          onPressed: onEditPressed,
          isPrimary: false,
        ),

        const SizedBox(width: 8),

        // Close Button
        _buildGoogleStyleButton(
          icon: Icons.close,
          tooltip: 'End route',
          onPressed: onClosePressed,
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildGoogleStyleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isPrimary
                ? Colors.blue.withAlpha(20)
                : Colors.grey.withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimary
                  ? Colors.blue.withAlpha(40)
                  : Colors.grey.withAlpha(30),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isPrimary
                ? Colors.blue.shade700
                : Colors.grey.shade600,
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

// Route Progress Indicator Widget
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
      curve: Curves.easeInOut,
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
        curve: Curves.easeInOut,
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
      decoration: BoxDecoration(
        color: widget.color.withAlpha(30),
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _animation.value,
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
