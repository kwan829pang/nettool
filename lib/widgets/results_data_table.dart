import 'package:flutter/material.dart';

class TableRowData {
  const TableRowData({
    required this.row,
    required this.searchText,
  });

  final DataRow row;
  final String searchText;
}

class ResultsDataTable extends StatefulWidget {
  const ResultsDataTable({
    super.key,
    required this.columns,
    required this.rowData,
    this.emptyMessage = 'No results yet. Run a scan to see data here.',
    this.noMatchMessage = 'No rows match your search.',
    this.searchHint = 'Search results…',
  });

  final List<DataColumn> columns;
  final List<TableRowData> rowData;
  final String emptyMessage;
  final String noMatchMessage;
  final String searchHint;

  @override
  State<ResultsDataTable> createState() => _ResultsDataTableState();
}

class _ResultsDataTableState extends State<ResultsDataTable> {
  final _searchController = TextEditingController();
  final _verticalScrollController = ScrollController();
  final _horizontalScrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  List<TableRowData> get _filteredRows {
    if (_query.isEmpty) return widget.rowData;
    return widget.rowData
        .where((item) => item.searchText.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRows;
    final hasData = widget.rowData.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    enabled: hasData,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                ),
                if (hasData) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${filtered.length} of ${widget.rowData.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !hasData
                ? Center(
                    child: Text(
                      widget.emptyMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          widget.noMatchMessage,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return Scrollbar(
                            controller: _verticalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _verticalScrollController,
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFF5F5F5),
                                    ),
                                    headingRowHeight: 44,
                                    dataRowMinHeight: 40,
                                    dataRowMaxHeight: 48,
                                    columns: widget.columns,
                                    rows: filtered.map((r) => r.row).toList(),
                                    columnSpacing: 32,
                                    horizontalMargin: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
