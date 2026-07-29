import sys

# Read the file
with open('lib/ui/screens/planner_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find line numbers for methods to delete
# _buildDayAgendaView starts at line 1356 (0-indexed: 1355)
# Find the end of _buildDayAgendaView (before next method)
# Then delete _buildJournalEntryItem, _journalMoodLabel, _buildPendingReminderCard, _buildTrackingRecordItem, _buildContactReminderItem

# Let's find the boundaries by searching for method signatures
lines_to_delete = set()

# Find _buildDayAgendaView end (before _buildJournalEntryItem)
for i in range(1355, len(lines)):
    if 'Widget _buildJournalEntryItem' in lines[i]:
        lines_to_delete.update(range(1355, i))
        break

# Find _buildJournalEntryItem end
for i in range(1355, len(lines)):
    if 'Widget _buildJournalEntryItem' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

# Find _journalMoodLabel end
for i in range(1355, len(lines)):
    if 'String _journalMoodLabel' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

# Find _buildPendingReminderCard end
for i in range(1355, len(lines)):
    if 'Widget _buildPendingReminderCard' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

# Find _buildTrackingRecordItem end
for i in range(1355, len(lines)):
    if 'Widget _buildTrackingRecordItem' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

# Find _buildContactReminderItem end
for i in range(1355, len(lines)):
    if 'Widget _buildContactReminderItem' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

print(f"Deleting {len(lines_to_delete)} lines from indices {sorted(lines_to_delete)[:10]}...")

# Filter out deleted lines
new_lines = [line for i, line in enumerate(lines) if i not in lines_to_delete]

# Write back
with open('lib/ui/screens/planner_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"Deleted {len(lines) - len(new_lines)} lines total")
