import 'package:flutter/material.dart';

class BudgetProvider extends ChangeNotifier {
  int _totalBudget = 0;
  Map<String, double> _allocations = {};
  List<String> _vendors = [];

  int get totalBudget => _totalBudget;
  Map<String, double> get allocations => _allocations;

  void initialize(List<String> vendors) {
    _vendors = vendors;
    _allocations = {};
    if (vendors.isNotEmpty && _totalBudget > 0) {
      final split = _totalBudget / vendors.length;
      for (var v in vendors) {
        _allocations[v] = split;
      }
    }
  }

  void setTotalBudget(int total) {
    _totalBudget = total;
    if (_vendors.isNotEmpty && _totalBudget > 0) {
      final split = _totalBudget / _vendors.length;
      for (var v in _vendors) {
        _allocations[v] = split;
      }
    }
    notifyListeners();
  }

  void updateAllocation(String vendor, double newValue) {
    if (!_allocations.containsKey(vendor)) return;
    
    double oldValue = _allocations[vendor]!;
    double difference = newValue - oldValue;
    
    String? largestOther;
    double maxVal = -1;
    
    for (var entry in _allocations.entries) {
      if (entry.key != vendor && entry.value > maxVal) {
        maxVal = entry.value;
        largestOther = entry.key;
      }
    }
    
    if (largestOther != null) {
      double newOtherValue = _allocations[largestOther]! - difference;
      if (newOtherValue < 0) {
        difference = _allocations[largestOther]!;
        newValue = oldValue + difference;
        newOtherValue = 0;
      }
      
      _allocations[vendor] = newValue;
      _allocations[largestOther] = newOtherValue;
      notifyListeners();
    }
  }
}
