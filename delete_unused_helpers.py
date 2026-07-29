import sys

# Read the file
with open('lib/ui/screens/planner_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Delete these unused helper methods (0-indexed line ranges):
# _buildJournalEntryItem: lines 1356-1424
# _journalMoodLabel: lines 1426-1437
# _buildPendingReminderCard: lines 1439-1494
# _buildTrackingRecordItem: lines 1496-1559
# _buildContactReminderItem: lines 1751-1805

lines_to_delete = set()

# _buildJournalEntryItem (1356-1424)
lines_to_delete.update(range(1356, 1425))

# _journalMoodLabel (1426-1437)
lines_to_delete.update(range(1426, 1438))

# _buildPendingReminderCard (1439-1494)
lines_to_delete.update(range(1439, 1495))

# _buildTrackingRecordItem (1496-1559)
lines_to_delete.update(range(1496, 1560))

# _buildContactReminderItem (1751-1805)
lines_to_delete.update(range(1751, 1806))

# Filter out deleted lines
new_lines = [line for i, line in enumerate(lines) if i not in lines_to_delete]

# Write back
with open('lib/ui/screens/planner_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"Deleted {len(lines) - len(new_lines)} lines")
