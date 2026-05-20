import 'package:flutter/material.dart';
import '../models/bundle.dart';

class BundleProvider extends ChangeNotifier {
  List<Bundle> _bundles = [];

  List<Bundle> get bundles => _bundles;

  void addBundle(Bundle bundle) {
    _bundles.add(bundle);
    notifyListeners();
  }

  void refreshBundles() {
    // For now, just notify to refresh UI
    notifyListeners();
  }
}