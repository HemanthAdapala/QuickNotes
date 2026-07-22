import '../models/note.dart';
import '../services/database_service.dart';

abstract class NotesRepository {
  Future<List<Note>> getNotes();
  Future<int> insertNote(Note note);
  Future<int> updateNote(Note note);
  Future<int> deleteNote(String id);
}

class SqliteNotesRepository implements NotesRepository {
  final DatabaseService _dbService;

  SqliteNotesRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<Note>> getNotes() async {
    return await _dbService.queryAll();
  }

  @override
  Future<int> insertNote(Note note) async {
    return await _dbService.insert(note);
  }

  @override
  Future<int> updateNote(Note note) async {
    return await _dbService.update(note);
  }

  @override
  Future<int> deleteNote(String id) async {
    return await _dbService.delete(id);
  }
}
