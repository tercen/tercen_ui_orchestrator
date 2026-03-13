void main() {
  // Simulate what toJson() returns
  Map m = {'name': 'test', 'id': '123', 'acl': {'owner': 'bob'}};
  
  print('m is Map: ${m is Map}');
  print('m is Map<String, dynamic>: ${m is Map<String, dynamic>}');
  
  // What the renderer does:
  dynamic item = m;
  final itemMap = item is Map<String, dynamic> ? item : <String, dynamic>{};
  print('itemMap: $itemMap');
  print('itemMap keys: ${itemMap.keys.toList()}');
}
