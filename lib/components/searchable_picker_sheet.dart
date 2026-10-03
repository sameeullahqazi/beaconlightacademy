import 'package:flutter/material.dart';

const Color _navyBlue = Color(0xFF041434);
const Color _selectedBgColor = Color(0xFFFFF9E6);

// Generic searchable single-select picker, shown as a modal bottom sheet.
// Built originally for the Diary screen's class dropdown, which broke
// Flutter's DropdownMenu widget at scale (RangeError on a coordinator
// account with 155 classes) - reused here for any {id, label} list that
// can similarly grow too large for a plain dropdown (e.g. New
// Correspondence's class/student pickers).
Future<void> showSearchablePicker({
  required BuildContext context,
  required List<Map<String, String>> items,
  required String idKey,
  required String labelKey,
  required String? selectedId,
  required ValueChanged<String> onSelected,
  String searchHint = 'Search...',
  String emptyText = 'No matching items.',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (context) => SearchablePickerSheet(
      items: items,
      idKey: idKey,
      labelKey: labelKey,
      selectedId: selectedId,
      onSelected: onSelected,
      searchHint: searchHint,
      emptyText: emptyText,
    ),
  );
}

class SearchablePickerSheet extends StatefulWidget {
  final List<Map<String, String>> items;
  final String idKey;
  final String labelKey;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final String searchHint;
  final String emptyText;

  const SearchablePickerSheet({
    super.key,
    required this.items,
    required this.idKey,
    required this.labelKey,
    required this.selectedId,
    required this.onSelected,
    this.searchHint = 'Search...',
    this.emptyText = 'No matching items.',
  });

  @override
  State<SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<SearchablePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
            .where((item) => (item[widget.labelKey] ?? '')
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4)),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  onChanged: (val) => setState(() => _query = val),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(widget.emptyText))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected =
                              item[widget.idKey] == widget.selectedId;
                          return ListTile(
                            title: Text(item[widget.labelKey] ?? ''),
                            selected: isSelected,
                            selectedTileColor: _selectedBgColor,
                            trailing: isSelected
                                ? const Icon(Icons.check, color: _navyBlue)
                                : null,
                            onTap: () {
                              widget.onSelected(item[widget.idKey]!);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
