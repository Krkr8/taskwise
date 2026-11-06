import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/providers.dart';
import '../../../sync/sync_api.dart';
import '../../../sync/sync_controller.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';

/// Opens the sign-in screen. Returns true once signed in.
Future<bool> showSignInPage(BuildContext context) async =>
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const SignInPage())) ??
    false;

/// Server address, username and password, and this device's name. A link
/// switches to creating the account first (needs the server's setup
/// secret, SPEC.md section 3.4).
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _form = GlobalKey<FormState>();
  late final _server = TextEditingController(
    text: ref.read(syncControllerProvider).serverUrl ?? '',
  );
  late final _username = TextEditingController(
    text: ref.read(syncControllerProvider).username ?? '',
  );
  final _password = TextEditingController();
  final _secret = TextEditingController();
  final _deviceName = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeviceName();
  }

  Future<void> _loadDeviceName() async {
    final db = ref.read(databaseProvider);
    final id = ref.read(deviceIdProvider);
    final device = await (db.select(
      db.devices,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    if (mounted && _deviceName.text.isEmpty) {
      _deviceName.text = device?.name ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_server, _username, _password, _secret, _deviceName]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .signIn(
            serverUrl: _server.text,
            username: _username.text.trim(),
            password: _password.text,
            deviceName: _deviceName.text.trim(),
            setupSecret: _createAccount ? _secret.text.trim() : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = signInErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String? required(String? value) =>
        (value ?? '').trim().isEmpty ? l10n.fieldRequired : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(Spacing.lg),
                children: [
                  TextFormField(
                    controller: _server,
                    decoration: InputDecoration(
                      labelText: l10n.signInServer,
                      hintText: l10n.signInServerHint,
                      prefixIcon: const Icon(Icons.dns_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (required(value) case final error?) return error;
                      try {
                        SyncApi.normalizeServerUrl(value!);
                        return null;
                      } on FormatException {
                        return l10n.signInErrorBadAddress;
                      }
                    },
                  ),
                  const SizedBox(height: Spacing.md),
                  if (_createAccount) ...[
                    Text(
                      l10n.signInCreateAccountHelp,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Spacing.sm),
                    TextFormField(
                      controller: _secret,
                      decoration: InputDecoration(
                        labelText: l10n.signInSetupSecret,
                        prefixIcon: const Icon(Icons.key_outlined),
                      ),
                      obscureText: true,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: required,
                    ),
                    const SizedBox(height: Spacing.md),
                  ],
                  TextFormField(
                    controller: _username,
                    decoration: InputDecoration(
                      labelText: l10n.signInUsername,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: required,
                  ),
                  const SizedBox(height: Spacing.md),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: l10n.signInPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    obscureText: !_showPassword,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) {
                      if ((value ?? '').isEmpty) return l10n.fieldRequired;
                      if (_createAccount && value!.length < 10) {
                        return l10n.passwordTooShort;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Spacing.md),
                  TextFormField(
                    controller: _deviceName,
                    decoration: InputDecoration(
                      labelText: l10n.signInDeviceName,
                      prefixIcon: const Icon(Icons.devices_outlined),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: required,
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: Spacing.md),
                    Text(
                      error,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: Spacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _createAccount
                                ? l10n.signInCreateButton
                                : l10n.signInButton,
                          ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _createAccount = !_createAccount;
                            _error = null;
                          }),
                    child: Text(
                      _createAccount
                          ? l10n.signInHaveAccount
                          : l10n.signInCreateAccount,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain-words explanation of a failed sign-in or account setup.
String signInErrorText(AppLocalizations l10n, Object error) => switch (error) {
  FormatException() => l10n.signInErrorBadAddress,
  SyncNetworkException() => l10n.signInErrorUnreachable,
  SyncHttpException(code: 'bad_response' || 'not_found') =>
    l10n.signInErrorNotTaskwise,
  SyncHttpException(code: 'rate_limited', :final retryAfter) =>
    l10n.signInErrorRateLimited(((retryAfter?.inSeconds ?? 900) / 60).ceil()),
  SyncHttpException(code: 'forbidden') => l10n.signInErrorWrongSecret,
  SyncHttpException(code: 'conflict') => l10n.signInErrorAccountExists,
  SyncHttpException(code: 'setup_disabled') => l10n.signInErrorSetupDisabled,
  SyncHttpException(status: 401) => l10n.signInErrorWrongPassword,
  SyncHttpException(:final code, :final message) => l10n.signInErrorOther(
    '$code: $message',
  ),
  _ => l10n.signInErrorOther('$error'),
};
