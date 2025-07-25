import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/draft_service.dart';
import '../models/draft_model.dart';
import '../providers/auth_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Timer? _periodicTimer;
  BuildContext? _context;
  DraftService? _draftService;
  AuthProvider? _authProvider;

  /// Initialize the notification service
  void initialize({
    required BuildContext context,
    required DraftService draftService,
    required AuthProvider authProvider,
  }) {
    _context = context;
    _draftService = draftService;
    _authProvider = authProvider;
    
    // Start periodic checks every 30 minutes
    startPeriodicChecks();
  }

  /// Start periodic draft checks
  void startPeriodicChecks() {
    // Cancel existing timer if any
    _periodicTimer?.cancel();
    
    // Set up timer to check every 30 minutes (1800 seconds)
    _periodicTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _checkDraftsAndNotify();
    });

    // Also do an initial check after 2 minutes of app usage
    Timer(const Duration(minutes: 2), () {
      _checkDraftsAndNotify();
    });
  }

  /// Stop periodic checks
  void stopPeriodicChecks() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Main method to check drafts and show notifications
  void _checkDraftsAndNotify() {
    if (_context == null || _draftService == null || _authProvider == null) {
      return;
    }

    try {
      // Get all drafts across all forms
      final allDrafts = _getAllDrafts();
      
      if (allDrafts.isEmpty) return;

      // Check for too many drafts
      _checkTooManyDrafts(allDrafts);
      
      // Check for old drafts
      _checkOldDrafts(allDrafts);
      
    } catch (e) {
      debugPrint('Error in draft notifications: $e');
    }
  }

  /// Get all drafts from all forms
  List<DraftModel> _getAllDrafts() {
    final allDrafts = <DraftModel>[];
    final forms = _authProvider?.forms ?? [];
    
    for (final form in forms) {
      final formId = form['form_id']?.toString();
      if (formId != null) {
        // Check both baseline and follow-up activity types
        final baselineDrafts = _draftService!.getDraftsByStatus(formId, 'Baseline', 'draft');
        final followUpDrafts = _draftService!.getDraftsByStatus(formId, 'Follow-up', 'draft');
        
        allDrafts.addAll(baselineDrafts);
        allDrafts.addAll(followUpDrafts);
      }
    }
    
    return allDrafts;
  }

  /// Check if there are too many drafts (>10)
  void _checkTooManyDrafts(List<DraftModel> drafts) {
    if (drafts.length > 10) {
      _showNotification(
        title: 'Too Many Drafts!',
        message: 'You have ${drafts.length} unsaved drafts. Consider committing some to free up space.',
        icon: Icons.warning,
        color: Colors.orange,
        action: 'View Drafts',
        onActionPressed: () => _navigateToDrafts(),
      );
    }
  }

  /// Check for drafts older than 3 days
  void _checkOldDrafts(List<DraftModel> drafts) {
    final now = DateTime.now();
    final oldDrafts = drafts.where((draft) {
      final daysDifference = now.difference(draft.timestamp).inDays;
      return daysDifference >= 3;
    }).toList();

    if (oldDrafts.isNotEmpty) {
      // Sort by oldest first
      oldDrafts.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final oldestDraft = oldDrafts.first;
      final daysSinceCreation = now.difference(oldestDraft.timestamp).inDays;
      
      _showNotification(
        title: 'Old Draft Detected',
        message: 'Draft "${_truncateTitle(oldestDraft.title)}" has been waiting for ${daysSinceCreation} days. Consider committing it.',
        icon: Icons.schedule,
        color: Colors.red,
        action: 'View Draft',
        onActionPressed: () => _navigateToSpecificDraft(oldestDraft),
      );
    }
  }

  /// Truncate title for notification display
  String _truncateTitle(String title) {
    if (title.length <= 30) return title;
    return '${title.substring(0, 30)}...';
  }

  /// Show notification using SnackBar
  void _showNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    String? action,
    VoidCallback? onActionPressed,
  }) {
    if (_context == null || !_shouldShowNotification()) return;

    // Store that we showed a notification to avoid spam
    _recordNotificationShown();

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action != null && onActionPressed != null
            ? SnackBarAction(
                label: action,
                textColor: Colors.white,
                onPressed: onActionPressed,
              )
            : null,
      ),
    );
  }

  /// Check if we should show a notification (rate limiting)
  bool _shouldShowNotification() {
    // Simple rate limiting - only show notifications once per hour
    const String prefsKey = 'last_notification_time';
    final lastNotificationTime = DateTime.tryParse(
      // You would typically use SharedPreferences here
      // For simplicity, we'll allow notifications for now
      DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()
    ) ?? DateTime.now().subtract(const Duration(hours: 2));
    
    final now = DateTime.now();
    final hoursSinceLastNotification = now.difference(lastNotificationTime).inHours;
    
    return hoursSinceLastNotification >= 1;
  }

  /// Record that we showed a notification
  void _recordNotificationShown() {
    // You would typically save this to SharedPreferences
    // For now, we'll skip the persistent storage
    debugPrint('Draft notification shown at ${DateTime.now()}');
  }

  /// Navigate to drafts page
  void _navigateToDrafts() {
    if (_context == null) return;
    
    // Navigate to home page where user can access drafts
    Navigator.of(_context!).pushNamedAndRemoveUntil(
      '/home_page',
      (route) => false,
    );
  }

  /// Navigate to a specific draft
  void _navigateToSpecificDraft(DraftModel draft) {
    if (_context == null) return;
    
    // Find the form for this draft
    final forms = _authProvider?.forms ?? [];
    final form = forms.firstWhere(
      (f) => f['form_id']?.toString() == draft.formId,
      orElse: () => null,
    );
    
    if (form != null) {
      Navigator.of(_context!).pushNamed(
        '/form_page',
        arguments: {
          'form_id': draft.formId,
          'form_title': form['title']?.toString() ?? 'Form',
          'activity_type': draft.answers['entity_type']?.toString() ?? 'Baseline',
          'draft': draft,
        },
      );
    }
  }

  /// Check drafts on demand (can be called manually)
  void checkNow() {
    _checkDraftsAndNotify();
  }

  /// Dispose of resources
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _context = null;
    _draftService = null;
    _authProvider = null;
  }
}
