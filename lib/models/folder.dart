class Folder {
  final String id;
  final String? userId;
  final String name;
  final String? parentId; // null represents root folder level
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? colorHex;
  final String? sticker;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? trashedByFolderId;
  final int version;
  final int lastSyncedVersion;

  Folder({
    required this.id,
    this.userId,
    required this.name,
    this.parentId,
    required this.createdAt,
    DateTime? updatedAt,
    this.colorHex,
    this.sticker,
    this.isDeleted = false,
    this.deletedAt,
    this.trashedByFolderId,
    this.version = 1,
    this.lastSyncedVersion = 0,
  }) : updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'colorHex': colorHex,
      'sticker': sticker,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
      'trashedByFolderId': trashedByFolderId,
      'version': version,
      'lastSyncedVersion': lastSyncedVersion,
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    final created = DateTime.parse(map['createdAt'] as String);
    return Folder(
      id: map['id'] as String,
      userId: map['userId'] as String?,
      name: map['name'] as String,
      parentId: map['parentId'] as String?,
      createdAt: created,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : created,
      colorHex: map['colorHex'] as String?,
      sticker: map['sticker'] as String?,
      isDeleted: map['isDeleted'] == 1 || map['isDeleted'] == true,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      trashedByFolderId: map['trashedByFolderId'] as String?,
      version: (map['version'] ?? 1) as int,
      lastSyncedVersion: (map['lastSyncedVersion'] ?? 0) as int,
    );
  }

  Folder copyWith({
    String? userId,
    String? name,
    String? parentId,
    DateTime? updatedAt,
    String? colorHex,
    bool clearColorHex = false,
    String? sticker,
    bool clearSticker = false,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? trashedByFolderId,
    bool clearTrashedByFolderId = false,
    int? version,
    int? lastSyncedVersion,
  }) {
    return Folder(
      id: id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorHex: clearColorHex ? null : (colorHex ?? this.colorHex),
      sticker: clearSticker ? null : (sticker ?? this.sticker),
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      trashedByFolderId: clearTrashedByFolderId
          ? null
          : (trashedByFolderId ?? this.trashedByFolderId),
      version: version ?? this.version,
      lastSyncedVersion: lastSyncedVersion ?? this.lastSyncedVersion,
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
      children
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (var child in children) {
        result.add(FolderWithDepth(child, depth));
        traverse(child.id, depth + 1);
      }
    }

    traverse(null, 0);

    // Add orphan folders (parentId is not null, but parent is missing)
    for (var folder in folders) {
      if (folder.parentId != null &&
          !folders.any((f) => f.id == folder.parentId)) {
        if (!result.any((r) => r.folder.id == folder.id)) {
          result.add(FolderWithDepth(folder, 0));
          traverse(folder.id, 1);
        }
      }
    }

    return result;
  }
}
