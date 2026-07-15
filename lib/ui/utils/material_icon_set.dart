// lib/ui/utils/material_icon_set.dart
// Material icon set for object type icon selection
import 'package:flutter/material.dart';

class MaterialIconSet {
  static const Map<String, IconData> allIcons = {
    // Common/Tasks
    'check_circle': Icons.check_circle,
    'check_circle_outline': Icons.check_circle_outline,
    'task': Icons.task,
    'assignment': Icons.assignment,
    'assignment_turned_in': Icons.assignment_turned_in,
    'done': Icons.done,
    'done_all': Icons.done_all,
    
    // Journal/Notes
    'book': Icons.book,
    'menu_book': Icons.menu_book,
    'description': Icons.description,
    'note': Icons.note,
    'article': Icons.article,
    'edit_note': Icons.edit_note,
    'sticky_note_2': Icons.sticky_note_2,
    
    // Habits
    'refresh': Icons.refresh,
    'autorenew': Icons.autorenew,
    'repeat': Icons.repeat,
    'loop': Icons.loop,
    'sync': Icons.sync,
    'update': Icons.update,
    
    // Goals
    'flag': Icons.flag,
    'emoji_events': Icons.emoji_events,
    'stars': Icons.stars,
    'track_changes': Icons.track_changes,
    'military_tech': Icons.military_tech,
    'workspace_premium': Icons.workspace_premium,
    
    // Projects
    'folder': Icons.folder,
    'folder_open': Icons.folder_open,
    'work': Icons.work,
    'business_center': Icons.business_center,
    'work_outline': Icons.work_outline,
    'account_tree': Icons.account_tree,
    
    // Events/Calendar
    'calendar_today': Icons.calendar_today,
    'event': Icons.event,
    'schedule': Icons.schedule,
    'alarm': Icons.alarm,
    'event_available': Icons.event_available,
    'event_busy': Icons.event_busy,
    
    // Ideas
    'lightbulb': Icons.lightbulb,
    'lightbulb_outline': Icons.lightbulb_outline,
    'tips_and_updates': Icons.tips_and_updates,
    'psychology': Icons.psychology,
    'auto_awesome': Icons.auto_awesome,
    'bolt': Icons.bolt,
    
    // People
    'person': Icons.person,
    'person_outline': Icons.person_outline,
    'people': Icons.people,
    'groups': Icons.groups,
    'person_add': Icons.person_add,
    'contacts': Icons.contacts,
    
    // Areas/Organizers
    'layers': Icons.layers,
    'category': Icons.category,
    'label': Icons.label,
    'label_outline': Icons.label_outline,
    'tag': Icons.tag,
    'bookmark': Icons.bookmark,
    
    // Activities
    'sports': Icons.sports,
    'directions_run': Icons.directions_run,
    'fitness_center': Icons.fitness_center,
    'timer': Icons.timer,
    'sports_esports': Icons.sports_esports,
    'sports_soccer': Icons.sports_soccer,
    
    // Resources
    'library_books': Icons.library_books,
    'local_library': Icons.local_library,
    'movie': Icons.movie,
    'music_note': Icons.music_note,
    'movie_filter': Icons.movie_filter,
    'headphones': Icons.headphones,
    
    // System
    'settings': Icons.settings,
    'tune': Icons.tune,
    'build': Icons.build,
    'admin_panel_settings': Icons.admin_panel_settings,
    'construction': Icons.construction,
    'engineering': Icons.engineering,
    
    // Social
    'share': Icons.share,
    'public': Icons.public,
    'link': Icons.link,
    'language': Icons.language,
    'share_arrow': Icons.share,
    'send': Icons.send,
    
    // Shopping
    'shopping_cart': Icons.shopping_cart,
    'shopping_bag': Icons.shopping_bag,
    'store': Icons.store,
    'point_of_sale': Icons.point_of_sale,
    'cart': Icons.shopping_cart,
    'local_mall': Icons.local_mall,
    
    // Pillars/Values
    'account_balance': Icons.account_balance,
    'diamond': Icons.diamond,
    'favorite': Icons.favorite,
    'favorite_border': Icons.favorite_border,
    'star': Icons.star,
    'star_border': Icons.star_border,
    
    // Actions
    'flash_on': Icons.flash_on,
    'power': Icons.power,
    'battery_charging_full': Icons.battery_charging_full,
    'rocket_launch': Icons.rocket_launch,
    
    // Trackers
    'bar_chart': Icons.bar_chart,
    'insert_chart': Icons.insert_chart,
    'show_chart': Icons.show_chart,
    'analytics': Icons.analytics,
    'insights': Icons.insights,
    'query_stats': Icons.query_stats,
    
    // Reminders
    'notifications': Icons.notifications,
    'notifications_active': Icons.notifications_active,
    'alarm_on': Icons.alarm_on,
    'add_alarm': Icons.add_alarm,
    'notification_important': Icons.notification_important,
    'ring_volume': Icons.ring_volume,
    
    // Inbox
    'inbox': Icons.inbox,
    'mail': Icons.mail,
    'drafts': Icons.drafts,
    'mark_email_unread': Icons.mark_email_unread,
    'email': Icons.email,
    'all_inbox': Icons.all_inbox,
    
    // Templates
    'dashboard': Icons.dashboard,
    'view_module': Icons.view_module,
    'grid_view': Icons.grid_view,
    'widgets': Icons.widgets,
    'view_quilt': Icons.view_quilt,
    'table_view': Icons.table_view,
    
    // Time
    'access_time': Icons.access_time,
    'history': Icons.history,
    'hourglass_empty': Icons.hourglass_empty,
    'hourglass_top': Icons.hourglass_top,
    
    // Misc
    'help_outline': Icons.help_outline,
    'info_outline': Icons.info_outline,
    'warning': Icons.warning,
    'error_outline': Icons.error_outline,
    'cancel': Icons.cancel,
  };

  static IconData? getIcon(String name) => allIcons[name];
  
  static List<String> get iconNames => allIcons.keys.toList()..sort();
  
  static List<String> get iconNamesUnsorted => allIcons.keys.toList();
}
