import sys

# Read the file
with open('lib/ui/screens/planner_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Delete these dead methods (0-indexed line ranges):
# _buildDayAgendaView: lines 1370-1498 (delete 1370-1498)
# _buildJournalEntryItem: lines 1500-1540 (delete 1500-1540)
# _journalMoodLabel: lines 1542-1553 (delete 1542-1553)
# _buildPendingReminderCard: lines 1555-1610 (delete 1555-1610)
# _buildTrackingRecordItem: lines 1612-1675 (delete 1612-1675)
# _buildContactReminderItem: lines 1895-1949 (delete 1895-1949)

# Keep track of cumulative deletions
lines_to_delete = set()

# _buildDayAgendaView (1370-1498)
lines_to_delete.update(range(1370, 1499))

# _buildJournalEntryItem (1500-1540)
lines_to_delete.update(range(1500, 1541))

# _journalMoodLabel (1542-1553)
lines_to_delete.update(range(1542, 1554))

# _buildPendingReminderCard (1555-1610)
lines_to_delete.update(range(1555, 1611))

# _buildTrackingRecordItem (1612-1675)
lines_to_delete.update(range(1612, 1676))

# _buildContactReminderItem (1895-1949)
lines_to_delete.update(range(1895, 1950))

# Filter out deleted lines
new_lines = [line for i, line in enumerate(lines) if i not in lines_to_delete]

# Write back
with open('lib/ui/screens/planner_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"Deleted {len(lines) - len(new_lines)} lines")
