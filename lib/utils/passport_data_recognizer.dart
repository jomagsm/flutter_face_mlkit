import 'package:flutter/cupertino.dart';

class PassportDataAnalyzer {
  List<String> _identificationNumberList = [];
  List<String> _paperNumbList = [];

  ValueChanged? onInnRecognized;
  ValueChanged? onPaperNumbRecognized;

  String? get identificationNumber =>
      _getMostFrequentElement(_identificationNumberList);

  String? get paperNumber => _getMostFrequentElement(_paperNumbList);

  void addPaperNumber(String paperNumber) => _paperNumbList.add(paperNumber);

  void addIdentificationNumber(String value) =>
      _identificationNumberList.add(value);

  bool isPassportNumber(text) => (text.length == 9 &&
      (text.startsWith('AN') || text.startsWith('ID')) &&
      _isNumber(text.substring(2, 9)));

  bool isIdentificationNumber(String text) => (text.length == 14 &&
      (text.startsWith('1') || text.startsWith('2')) &&
      _isNumber(text));

  bool _isNumber(String str) {
    try {
      int value = int.tryParse(str)!;
      print('INT VALUE = $value ');
      return true;
    } catch (_) {
      return false;
    }
  }

  T? _getMostFrequentElement<T>(List<T> items) {
    if (items.isEmpty) {
      return null;
    }
    var set = items.toSet();
    int maxEntries = 0;
    T finalElement = set.first;
    set.map((element) {
      var elementEntries = items.where((e) => e == element).length;
      if (elementEntries > maxEntries) {
        maxEntries = elementEntries;
        finalElement = element;
      }
    });

    return finalElement;
  }
}
