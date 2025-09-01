import 'package:flutter/foundation.dart';
import '../models/logsheet_data.dart';
import '../models/generator.dart';

class LogsheetState with ChangeNotifier {
  LogsheetData? _currentData;
  bool _isEditMode = false;
  bool _isDataLocked = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  LogsheetData? get currentData => _currentData;
  bool get isEditMode => _isEditMode;
  bool get isDataLocked => _isDataLocked;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Setters
  void setCurrentData(LogsheetData? data) {
    _currentData = data;
    notifyListeners();
  }

  void setEditMode(bool isEdit) {
    _isEditMode = isEdit;
    notifyListeners();
  }

  void setDataLocked(bool isLocked) {
    _isDataLocked = isLocked;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _currentData = null;
    _isEditMode = false;
    _isDataLocked = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

class GeneratorState with ChangeNotifier {
  List<Generator> _generators = [];
  Generator? _selectedGenerator;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Generator> get generators => _generators;
  Generator? get selectedGenerator => _selectedGenerator;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Setters
  void setGenerators(List<Generator> generators) {
    _generators = generators;
    notifyListeners();
  }

  void setSelectedGenerator(Generator? generator) {
    _selectedGenerator = generator;
    notifyListeners();
  }

  void updateGenerator(Generator updatedGenerator) {
    final index = _generators.indexWhere((g) => g.id == updatedGenerator.id);
    if (index != -1) {
      _generators[index] = updatedGenerator;
      if (_selectedGenerator?.id == updatedGenerator.id) {
        _selectedGenerator = updatedGenerator;
      }
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
