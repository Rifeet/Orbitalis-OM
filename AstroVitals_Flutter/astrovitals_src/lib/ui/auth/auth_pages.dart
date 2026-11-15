/// Sign in / Sign up - the entry gate added for the crew console.
///
/// Design language follows the reference app: same background (grid + glow),
/// same panel (radius 18, --surf), pill buttons and inline validation with
/// error text under each field and a disabled submit until the form is valid.
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../core/data/app_state.dart';
import '../../core/validation/validators.dart';
import '../pages/shell.dart' show AVBackground;
import '../widgets/common.dart';

class AuthGate extends StatefulWidget {
  final AppState st;
  const AuthGate({super.key, required this.st});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool signup = false;

  void _toggle() {
    setState(() => signup = !signup);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AVBackground(
        palette: p,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _brandHeader(context),
                    const SizedBox(height: 18),
                    Panel(
                      padding: const EdgeInsets.all(22),
                      child: signup
                          ? _SignUpForm(st: widget.st, onSwitch: _toggle)
                          : _SignInForm(st: widget.st, onSwitch: _toggle),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'AstroVitals supports self-checks and does not replace your flight surgeon. Data shown is a demo.',
                      textAlign: TextAlign.center,
                      style: AVText.bodyStyle(12, color: p.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandHeader(BuildContext context) {
    final p = avp(context);
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.blue, width: 1.5),
          ),
          child: CustomPaint(
            painter: _AuthLogoPainter(p.blue, p.tierT(0)),
          ),
        ),
        const SizedBox(height: 10),
        Text('ASTROVITALS',
            style: AVText.displayStyle(22, w: FontWeight.w600, color: p.fg, ls: 2.64)),
        const SizedBox(height: 4),
        Text('Crew health console',
            style: AVText.bodyStyle(14, color: p.muted)),
      ],
    );
  }
}

class _SignInForm extends StatefulWidget {
  final AppState st;
  final VoidCallback onSwitch;
  const _SignInForm({required this.st, required this.onSwitch});

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  String? emailErr, passErr;

  bool get valid =>
      validateEmail(email.text).ok &&
      validatePassword(password.text).ok;

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.st.signIn(email.text, password.text);
  }

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sign in', style: AVText.displayStyle(20, w: FontWeight.w600, color: p.fg)),
        const SizedBox(height: 4),
        Text('Use your crew account to open the health console.',
            style: AVText.bodyStyle(14, color: p.muted)),
        const SizedBox(height: 16),
        Text('Email', style: AVText.bodyStyle(13, color: p.muted)),
        const SizedBox(height: 4),
        AVTextField(
          controller: email,
          hint: 'name@agency.space',
          keyboardType: TextInputType.emailAddress,
          error: emailErr != null,
          onChanged: (v) => setState(() => emailErr = validateEmail(v).error),
        ),
        ErrorText(emailErr),
        const SizedBox(height: 8),
        Text('Password', style: AVText.bodyStyle(13, color: p.muted)),
        const SizedBox(height: 4),
        AVTextField(
          controller: password,
          obscure: obscure,
          error: passErr != null,
          onChanged: (v) => setState(() => passErr = validatePassword(v).error),
          suffix: _eyeToggle(),
        ),
        ErrorText(passErr),
        const SizedBox(height: 12),
        AVButton('Sign in', expand: true, onPressed: valid ? _submit : null),
        const SizedBox(height: 6),
        Center(child: AVLink('New crew member? Create an account', onPressed: widget.onSwitch)),
        const SizedBox(height: 2),
        Center(
          child: AVLink('Fill the demo crew account', onPressed: () {
            setState(() {
              email.text = 'lena.ortiz@astrovitals.demo';
              password.text = 'passw0rd1';
              emailErr = validateEmail(email.text).error;
              passErr = validatePassword(password.text).error;
            });
          }),
        ),
      ],
    );
  }

  Widget _eyeToggle() {
    final p = avp(context);
    return GestureDetector(
      onTap: () => setState(() => obscure = !obscure),
      child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20, color: p.muted),
    );
  }
}

class _SignUpForm extends StatefulWidget {
  final AppState st;
  final VoidCallback onSwitch;
  const _SignUpForm({required this.st, required this.onSwitch});

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final name = TextEditingController();
  final role = TextEditingController(text: 'Flight engineer');
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool obscure = true;
  String? nameErr, roleErr, emailErr, passErr, confirmErr;

  bool get valid =>
      validateProfileName(name.text).ok &&
      validateProfileRole(role.text).ok &&
      validateEmail(email.text).ok &&
      validatePassword(password.text).ok &&
      validatePasswordConfirm(confirm.text, password.text).ok;

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.st.signUp(name.text, role.text, email.text, password.text);
  }

  @override
  Widget build(BuildContext context) {
    final p = avp(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sign up', style: AVText.displayStyle(20, w: FontWeight.w600, color: p.fg)),
        const SizedBox(height: 4),
        Text('Create your crew profile. It is saved on this device.',
            style: AVText.bodyStyle(14, color: p.muted)),
        const SizedBox(height: 16),
        Text('Name', style: AVText.bodyStyle(13, color: p.muted)),
        const SizedBox(height: 4),
        AVTextField(
          controller: name,
          hint: 'Lena Ortiz',
          maxLength: 40,
          error: nameErr != null,
          onChanged: (v) => setState(() => nameErr = validateProfileName(v).error),
        ),
        ErrorText(nameErr),
        const SizedBox(height: 8),
        Text('Role', style: AVText.bodyStyle(13, color: p.muted)),
        const SizedBox(height: 4),
        AVTextField(
          controller: role,
          maxLength: 40,
          error: roleErr != null,
          onChanged: (v) => setState(() => roleErr = validateProfileRole(v).error),
        ),
        ErrorText(roleErr),
        const SizedBox(height: 8),
        Text('Email', style: AVText.bodyStyle(13, color: p.muted)),
        const SizedBox(height: 4),
        AVTextField(
          controller: email,
          hint: 'name@agency.space',
          keyboardType: TextInputType.emailAddress,
          error: emailErr != null,
          onChanged: (v) => setState(() => emailErr = validateEmail(v).error),
        ),
        ErrorText(emailErr),
        const SizedBox(height: 8),
        Text('Password', style: AVText.bodyStyle(13, color: p.muted)),
        const SizedBox(height: 4),
        AVTextField(
          controller: password,
          obscure: obscure,
          error: passErr != null,
          onChanged: (v) {
            setState(() {
              passErr = validatePassword(v).error;
              confirmErr = confirm.text.isEmpty
                  ? null
                  : validatePasswordConfirm(confirm.text, v).error;
            });
          },
          suffix: _eyeToggle(),
        ),
        ErrorText(passErr),
        const SizedBox(height: 8),
        Text('Confirm password', style: AVText.bodyStyle(13, color: p.muted)),
        const SizedBox(height: 4),
        AVTextField(
          controller: confirm,
          obscure: obscure,
          error: confirmErr != null,
          onSubmitted: valid ? (_) => _submit() : null,
          onChanged: (v) =>
              setState(() => confirmErr = validatePasswordConfirm(v, password.text).error),
        ),
        ErrorText(confirmErr),
        const SizedBox(height: 12),
        AVButton('Sign up', expand: true, onPressed: valid ? _submit : null),
        const SizedBox(height: 6),
        Center(
          child: AVLink('Already have an account? Sign in', onPressed: widget.onSwitch),
        ),
      ],
    );
  }

  Widget _eyeToggle() {
    final p = avp(context);
    return GestureDetector(
      onTap: () => setState(() => obscure = !obscure),
      child: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20, color: p.muted),
    );
  }
}

class _AuthLogoPainter extends CustomPainter {
  final Color ring;
  final Color pulse;
  _AuthLogoPainter(this.ring, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.42,
        Paint()..style = PaintingStyle.stroke..color = ring..strokeWidth = 1.5);
    final path = Path()
      ..moveTo(s * 0.13, s * 0.53)
      ..lineTo(s * 0.34, s * 0.53)
      ..lineTo(s * 0.42, s * 0.35)
      ..lineTo(s * 0.55, s * 0.71)
      ..lineTo(s * 0.63, s * 0.53)
      ..lineTo(s * 0.87, s * 0.53);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = pulse
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_AuthLogoPainter old) => old.ring != ring || old.pulse != pulse;
}
