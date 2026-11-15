/// Validation layer - immediate validation for every user-entered value.
///
/// Rules (per the team brief + contract "Validation" row):
///  * LIM range check  - every numeric reading must sit inside LIM;
///  * cross-field check - diastolic must be lower than systolic;
///  * sleep check - bedtime + wake time must give 0.5..16 h, wake-ups 0..20;
///  * format checks - dose text, inventory code, journal, profile fields;
///  * freshness + duplicate checks live in the repository / sync queue.
library;

import '../contract/limits.dart';

class ValidationResult {
  final bool ok;
  final String? error;
  const ValidationResult.ok() : ok = true, error = null;
  const ValidationResult.err(this.error) : ok = false;
}

/// numeric reading validation against LIM (port of the design's form logic)
ValidationResult validateNumber(String raw, String key) {
  final lim = kLim[key];
  if (lim == null) return const ValidationResult.ok();
  final n = double.tryParse(raw.replaceAll(',', '.'));
  if (raw.trim().isEmpty || n == null) {
    return ValidationResult.err('${lim.label} must be a number between ${_num(lim.min)} and ${_num(lim.max)}.');
  }
  if (n < lim.min || n > lim.max) {
    return ValidationResult.err('${lim.label} must be a number between ${_num(lim.min)} and ${_num(lim.max)}.');
  }
  return const ValidationResult.ok();
}

String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

/// cross-field: diastolic < systolic
ValidationResult validateBpPair(String sysRaw, String diaRaw) {
  final sys = double.tryParse(sysRaw.replaceAll(',', '.'));
  final dia = double.tryParse(diaRaw.replaceAll(',', '.'));
  if (sys != null && dia != null && dia >= sys) {
    return const ValidationResult.err('Diastolic must be lower than systolic.');
  }
  return const ValidationResult.ok();
}

/// sleep form: bed + up times, wake-ups count, resulting duration
ValidationResult validateSleep(String bed, String up, String wakeRaw) {
  if (bed.isEmpty || up.isEmpty) {
    return const ValidationResult.err('Enter both bedtime and wake time.');
  }
  final wk = int.tryParse(wakeRaw);
  if (wk == null || wk < 0 || wk > 20) {
    return const ValidationResult.err('Wake-ups must be between 0 and 20.');
  }
  final bedM = _toMin(bed), upM = _toMin(up);
  if (bedM < 0) {
    return const ValidationResult.err('Use a valid bedtime (HH:MM).');
  }
  if (upM < 0) {
    return const ValidationResult.err('Use a valid wake time (HH:MM).');
  }
  final mins = ((upM - bedM) % 1440 + 1440) % 1440;
  final hrs = mins / 60;
  if (hrs < 0.5 || hrs > 16) {
    return ValidationResult.err('That gives ${hrs.toStringAsFixed(1)} hours. Check the times.');
  }
  return const ValidationResult.ok();
}

int _toMin(String t) {
  final p = t.split(':');
  if (p.length != 2) return -1;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return -1;
  return h * 60 + m;
}

/// mission day
ValidationResult validateMissionDay(String raw, int total) {
  final v = int.tryParse(raw);
  if (v == null || v < 1 || v > total) {
    return ValidationResult.err('Mission day must be a whole number between 1 and $total.');
  }
  return const ValidationResult.ok();
}

/// medication dose text (optional field, validated when present)
ValidationResult validateMedDose(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return const ValidationResult.ok();
  if (t.length > 30) {
    return const ValidationResult.err('Keep the dose under 30 characters.');
  }
  final re = RegExp(r'^\d+(\.\d+)?\s*(mg|ml|mcg|iu|g|units?|tablets?|spray|patch)?$', caseSensitive: false);
  if (!re.hasMatch(t)) {
    return const ValidationResult.err('Dose looks wrong - use a number with a unit, e.g. 400 mg.');
  }
  return const ValidationResult.ok();
}

/// medication name: must come from the list (select) - always valid, but keep
/// a guard for empty states.
ValidationResult validateMedName(String name) {
  if (name.trim().isEmpty) {
    return const ValidationResult.err('Pick a medication from the list.');
  }
  return const ValidationResult.ok();
}

/// inventory item code / name
ValidationResult validateInvCode(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return const ValidationResult.err('Enter an item name or barcode.');
  if (t.length > 40) return const ValidationResult.err('Keep the item name under 40 characters.');
  return const ValidationResult.ok();
}

/// journal entry
ValidationResult validateJournal(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return const ValidationResult.err('Write a line first.');
  if (t.length > 1000) return const ValidationResult.err('Keep the entry under 1000 characters.');
  return const ValidationResult.ok();
}

/// profile name / role
ValidationResult validateProfileName(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return const ValidationResult.err('Enter your name.');
  if (t.length > 40) return const ValidationResult.err('Keep the name under 40 characters.');
  return const ValidationResult.ok();
}

ValidationResult validateProfileRole(String raw) {
  if (raw.trim().length > 40) return const ValidationResult.err('Keep the role under 40 characters.');
  return const ValidationResult.ok();
}

/// auth: email format (used by the sign in / sign up forms, live per keystroke)
ValidationResult validateEmail(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return const ValidationResult.err('Enter your email.');
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  if (!re.hasMatch(t)) return const ValidationResult.err('Enter a valid email address, e.g. name@agency.space.');
  return const ValidationResult.ok();
}

/// auth: password - 8+ characters, at least one letter and one digit
ValidationResult validatePassword(String raw) {
  if (raw.isEmpty) return const ValidationResult.err('Enter a password.');
  if (raw.length < 8) {
    return const ValidationResult.err('Use at least 8 characters.');
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(raw) || !RegExp(r'\d').hasMatch(raw)) {
    return const ValidationResult.err('Mix letters and numbers.');
  }
  return const ValidationResult.ok();
}

/// auth: confirm field must match the password
ValidationResult validatePasswordConfirm(String raw, String password) {
  if (raw.isEmpty) return const ValidationResult.err('Repeat the password.');
  if (raw != password) return const ValidationResult.err('The two passwords do not match.');
  return const ValidationResult.ok();
}

/// water amounts (mL) - clamp to sane bounds
ValidationResult validateWaterMl(double ml) {
  if (ml < 0) return const ValidationResult.err('Water cannot go below zero.');
  if (ml > 10000) return const ValidationResult.err('That is more than 10 L a day - check the amount.');
  return const ValidationResult.ok();
}

/// photo attachment limits (port of the design's file input checks)
ValidationResult validatePhoto(int currentCount, bool isImage, int sizeBytes) {
  if (currentCount >= 6) {
    return const ValidationResult.err('You can keep up to 6 photos here. Remove one first.');
  }
  if (!isImage) return const ValidationResult.err('Only image files can be added.');
  if (sizeBytes > 8 * 1024 * 1024) {
    return const ValidationResult.err('That image is over 8 MB. Choose a smaller one.');
  }
  return const ValidationResult.ok();
}

/// weekly questionnaire completeness
ValidationResult validateWeekly(List<int> answers) {
  if (answers.any((a) => a == 0)) {
    return const ValidationResult.err('Answer all five questions before saving.');
  }
  return const ValidationResult.ok();
}

/// contract-level plausibility for readings produced by the engine layer:
/// used by the repository before enqueueing.
ValidationResult validateReadingValue(String key, double value) {
  final lim = kLim[key];
  if (lim == null) return const ValidationResult.ok();
  if (value < lim.min || value > lim.max) {
    return ValidationResult.err('${lim.label} $value is outside the valid range ${_num(lim.min)} to ${_num(lim.max)}.');
  }
  return const ValidationResult.ok();
}
