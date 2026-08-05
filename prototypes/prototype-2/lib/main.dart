import 'package:flutter/material.dart';

import 'app/family_compass_app.dart';
import 'prototype/prototype_scenario_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    FamilyCompassApp(
      controller: PrototypeScenarioController(),
    ),
  );
}
