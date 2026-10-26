import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Official maintainer destination. Preferences, themes and imports cannot set it.
const officialSupportUrl = 'https://paypal.me/2hussam4';

Future<void> openOfficialSupport() =>
    const MethodChannel('life_manager/file_dialog')
        .invokeMethod<void>('openResource', officialSupportUrl);

class SupportButton extends StatefulWidget {
  const SupportButton({
    super.key,
    this.claimIntroduction,
    this.reducedMotion = false,
  });
  final Future<bool> Function()? claimIntroduction;
  final bool reducedMotion;

  @override
  State<SupportButton> createState() => _SupportButtonState();
}

class _SupportButtonState extends State<SupportButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? timeout;
  bool introductory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => introduce());
  }

  Future<void> introduce() async {
    try {
      if (await widget.claimIntroduction?.call() != true || !mounted) return;
      setState(() => introductory = true);
      if (!widget.reducedMotion && !MediaQuery.disableAnimationsOf(context)) {
        pulse.repeat(reverse: true);
      }
      timeout = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        pulse.stop();
        setState(() => introductory = false);
      });
    } catch (_) {
      // Discovery is optional; failed local persistence must not block the app.
    }
  }

  @override
  void dispose() {
    timeout?.cancel();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: introductory
            ? Theme.of(context).colorScheme.primary
                  .withValues(alpha: .12 + pulse.value * .10)
            : Colors.transparent,
      ),
      child: child,
    ),
    child: IconButton(
      tooltip: 'Support Todorbit',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const SupportDialog(),
      ),
      icon: const Icon(Icons.volunteer_activism_outlined, size: 20),
    ),
  );
}

class SupportDialog extends StatefulWidget {
  const SupportDialog({super.key, this.open = openOfficialSupport});
  final Future<void> Function() open;

  @override
  State<SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<SupportDialog> {
  bool opening = false;
  String? error;

  Future<void> support() async {
    setState(() {
      opening = true;
      error = null;
    });
    try {
      await widget.open();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not open your browser. Try again or visit $officialSupportUrl.',
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    constraints: const BoxConstraints(maxWidth: 440),
    title: Row(
      children: [
        const ExcludeSemantics(
          child: Icon(Icons.favorite, size: 22, color: Color(0xFFDC3545)),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('Enjoying Todorbit?')),
        IconButton(
          tooltip: 'Close support',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'If Todorbit makes your day a little easier, consider buying me a coffee! Your support helps me keep the app free and make it even better for everyone.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: opening ? null : support,
          icon: const Icon(Icons.coffee_outlined),
          label: Text(opening ? 'Opening PayPal…' : 'Buy Me a Coffee'),
        ),
        const SizedBox(height: 8),
        Text(
          'Support via PayPal',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional support. Opens PayPal in your browser.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SelectableText(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );
}
