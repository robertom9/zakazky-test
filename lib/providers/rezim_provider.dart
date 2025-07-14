import 'package:flutter/material.dart';

class RezimProvider with ChangeNotifier {
  bool tichyRezim = false;
  bool vibracie = true;

  void toggleTichy() {
    tichyRezim = !tichyRezim;
    notifyListeners();
  }

  void setTichy(bool val) {
    tichyRezim = val;
    notifyListeners();
  }

  void toggleVibracie() {
    vibracie = !vibracie;
    notifyListeners();
  }

  void setVibracie(bool val) {
    vibracie = val;
    notifyListeners();
  }
}
