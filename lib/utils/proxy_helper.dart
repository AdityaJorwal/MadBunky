import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

/// Triggers the "Proxy" effect:
/// 1. Rich Haptics (Heavy Impact)
/// 2. Screen Edge Glow Animation (via ThunderOverlay provider)
void triggerProxyEffect(BuildContext context, WidgetRef ref) {
  // 1. Rich Haptics (handled by SparkWidget mostly, but reinforce here for impact)
  HapticFeedback.heavyImpact();

  // 2. Trigger Global Edge Glow Overlay
  ref.read(proxyEffectTriggerProvider.notifier).state++;
}
