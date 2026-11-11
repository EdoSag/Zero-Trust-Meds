import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Meds in the suite. Not in the core's `ZtSuite` list yet, so the other
/// apps don't link to it before it's released.
const ZtSuiteApp medsSuiteApp = ZtSuiteApp(
  appId: 'meds',
  name: 'Meds',
  tagline: 'Children\'s medicines, shared by caregivers',
  icon: Icons.medication_outlined,
  accent: Color(0xFFF43F5E), // rose
  androidPackage: 'dev.sagron.zerotrustmeds',
);

const ZtAppConfig medsAppConfig = ZtAppConfig(
  appId: 'meds',
  displayName: 'Zero-Trust Meds',
  accent: Color(0xFFF43F5E),
);

/// Children, medicines and treatments are written by a child's admins only;
/// caregivers write dose records (enforced by the server too).
const SpacePolicy medsSpacePolicy = SpacePolicy(
  adminOnlyKinds: {'child', 'medication', 'treatment'},
);

/// Missed is amber with an icon, never colour alone.
const Color missedAmber = Color(0xFFF59E0B);
