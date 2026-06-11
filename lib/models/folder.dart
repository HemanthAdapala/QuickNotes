class Folder {
  final String id;
  final String name;
  final String? parentId; // null represents root folder level
  final DateTime createdAt;

  Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parentId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class FolderWithDepth {
  final Folder folder;
  final int depth;
  FolderWithDepth(this.folder, this.depth);
}

class FolderUtils {
  static List<FolderWithDepth> getHierarchicalFolders(List<Folder> folders) {
    final List<FolderWithDepth> result = [];
    
    void traverse(String? parentId, int depth) {
      final children = folders.where((f) => f.parentId == parentId).toList();
      children.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (var child in children) {
        result.add(FolderWithDepth(child, depth));
        traverse(child.id, depth + 1);
      }
    }
    
    traverse(null, 0);
    
    // Add orphan folders (parentId is not null, but parent is missing)
    for (var folder in folders) {
      if (folder.parentId != null && !folders.any((f) => f.id == folder.parentId)) {
        if (!result.any((r) => r.folder.id == folder.id)) {
          result.add(FolderWithDepth(folder, 0));
          traverse(folder.id, 1);
        }
      }
    }
    
    return result;
  }
}

