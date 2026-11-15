/// LIM - plausibility limits used by the validation layer and the contract's
/// "Validation: LIM range check" row. [min, max, label].
library;

class LimRule {
  final double min;
  final double max;
  final String label;
  final double step;
  const LimRule(this.min, this.max, this.label, {this.step = 1});
}

const Map<String, LimRule> kLim = {
  'hr': LimRule(25, 220, 'Heart rate'),
  'sys': LimRule(60, 260, 'Systolic pressure'),
  'dia': LimRule(30, 160, 'Diastolic pressure'),
  'glu': LimRule(20, 600, 'Glucose'),
  'temp': LimRule(32, 43, 'Temperature', step: 0.1),
  'sleep': LimRule(0, 16, 'Sleep'),
  'spo2': LimRule(50, 100, 'SpO₂'),
  'ex': LimRule(0, 600, 'Exercise'),
  'rad': LimRule(0, 50, 'Radiation dose', step: 0.01),
  'co2': LimRule(300, 30000, 'CO₂', step: 10),
  'hum': LimRule(0, 100, 'Humidity'),
  'ctemp': LimRule(5, 45, 'Cabin temperature', step: 0.1),
  'noise': LimRule(20, 140, 'Noise'),
  'resp': LimRule(4, 60, 'Breathing rate'),
  'mass': LimRule(30, 200, 'Body mass', step: 0.1),
};

/// manual entry specs (MAN from the design): key, label, step
const Map<String, List<List<dynamic>>> kManualSpec = {
  'hr': [['hr', 'Heart rate (bpm)', 1]],
  'bp': [['sys', 'Systolic (mmHg)', 1], ['dia', 'Diastolic (mmHg)', 1]],
  'spo2': [['spo2', 'SpO₂ (%)', 1]],
  'glu': [['glu', 'Glucose (mg/dL)', 1]],
  'temp': [['temp', 'Temperature (°C)', 0.1]],
  'ex': [['ex', 'Minutes', 1]],
  'rad': [['rad', 'Dose today (mSv)', 0.01]],
  'co2': [['co2', 'CO₂ (ppm)', 10]],
  'hum': [['hum', 'Humidity (% RH)', 1]],
  'ctemp': [['ctemp', 'Temperature (°C)', 0.1]],
  'noise': [['noise', 'Noise (dBA)', 1]],
  'resp': [['resp', 'Breaths per minute', 1]],
  'mass': [['mass', 'Mass (kg)', 0.1]],
};

/// DEV device table: device, route, kind, minutes since last update
class DeviceSpec {
  final String device;
  final String route;
  final String kind;
  final int ageMin;
  const DeviceSpec(this.device, this.route, this.kind, this.ageMin);
}

const Map<String, DeviceSpec> kDevices = {
  'rad': DeviceSpec('Crew Active Dosimeter', 'Bluetooth to station computer', 'direct', 55),
  'spo2': DeviceSpec('Bio-Monitor shirt', 'Base download', 'direct', 14),
  'resp': DeviceSpec('Bio-Monitor shirt', 'Base download', 'direct', 14),
  'temp': DeviceSpec('Thermo-Mini sensor', 'Sensor download', 'direct', 31),
  'sleep': DeviceSpec('Actiwatch', 'Wrist download', 'direct', 410),
  'ex': DeviceSpec('Exercise log', 'Copied to MEC laptop', 'direct', 95),
  'hr': DeviceSpec('Wrist strap', 'Copied to MEC laptop', 'direct', 14),
  'sys': DeviceSpec('BP cuff and electrodes', 'USB or Bluetooth', 'direct', 38),
  'dia': DeviceSpec('BP cuff and electrodes', 'USB or Bluetooth', 'direct', 38),
  'glu': DeviceSpec('Glucometer', 'Relayed to control centre', 'partial', 180),
  'mass': DeviceSpec('SLAMMD mass device', 'Transfer not documented', 'partial', 2880),
  'co2': DeviceSpec('MCA analyzer', 'Cabin air tubes', 'direct', 1),
  'hum': DeviceSpec('Multi-Gas Monitor', 'Cabin sensor', 'direct', 1),
  'ctemp': DeviceSpec('Cabin air control', 'Not documented', 'partial', 1),
  'noise': DeviceSpec('Sound level meter', 'RS-232 cable to MEC', 'direct', 4),
};
