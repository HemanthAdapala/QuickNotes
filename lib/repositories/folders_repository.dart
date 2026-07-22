import '../models/folder.dart';
import '../services/database_service.dart';

abstract class FoldersRepository {
  Future<List<Folder>> getFolders();
  Future<int> insertFolder(Folder folder);
  Future<int> updateFolder(Folder folder);
  Future<int> deleteFolder(String id);
}

class SqliteFoldersRepository implements FoldersRepository {
  final DatabaseService _dbService;

  SqliteFoldersRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<Folder>> getFolders() async {
    return await _dbService.queryAllFolders();
  }

  @override
  Future<int> insertFolder(Folder folder) async {
    return await _dbService.insertFolder(folder);
  }

  @override
  Future<int> updateFolder(Folder folder) async {
    return await _dbService.updateFolder(folder);
  }

  @override
  Future<int> deleteFolder(String id) async {
    return await _dbService.deleteFolder(id);
  }
}
