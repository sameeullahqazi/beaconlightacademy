import 'package:flutter/material.dart';
import 'package:bla_flutter_app/themes/constants.dart';

class MultiSelectDropdown extends StatelessWidget {
  final String label;
  final List<Map<String, String>> items; // [{'id': '1', 'name': '...'}, ...]
  final List<String> selectedIds;
  final Function(List<String>) onChanged;

  const MultiSelectDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Determine display text
    String displayText = label;
    if (selectedIds.isNotEmpty) {
      final selectedNames = items
          .where((item) => selectedIds.contains(item['id']))
          .map((item) => item['name'])
          .toList();
      displayText = selectedNames.join(", ");
    }

    return InkWell(
      onTap: () => _showSelectionDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4), // Square corners like web
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      selectedIds.isEmpty ? Colors.grey.shade600 : Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showSelectionDialog(BuildContext context) {
    final tempSelectedIds = List<String>.from(selectedIds);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Select $label"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    final isChecked = tempSelectedIds.contains(item['id']);
                    return CheckboxListTile(
                      title: Text(item['name']!),
                      value: isChecked,
                      activeColor: AppColors.purplePrimary,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            tempSelectedIds.add(item['id']!);
                          } else {
                            tempSelectedIds.remove(item['id']!);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL"),
                ),
                TextButton(
                  onPressed: () {
                    onChanged(tempSelectedIds);
                    Navigator.pop(context);
                  },
                  child: const Text("OK",
                      style: TextStyle(color: AppColors.purplePrimary)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
