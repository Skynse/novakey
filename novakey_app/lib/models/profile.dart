import 'control_binding.dart';

class Combination {
  Combination({
    required this.held,
    required this.trigger,
    required this.binding,
  });
  final String held, trigger;
  ControlBinding binding;
  Map<String, dynamic> toJson() => {
    'held': held,
    'trigger': trigger,
    'binding': binding.toJson(),
  };
  factory Combination.fromJson(Map<String, dynamic> j) => Combination(
    held: j['held'],
    trigger: j['trigger'],
    binding: ControlBinding.fromJson(Map<String, dynamic>.from(j['binding'])),
  );
}

class Profile {
  Profile({
    required this.id,
    required this.name,
    this.application = '',
    Map<String, ControlBinding>? bindings,
    List<Combination>? combinations,
  }) : bindings = bindings ?? {},
       combinations = combinations ?? [];
  final String id;
  String name, application;
  final Map<String, ControlBinding> bindings;
  final List<Combination> combinations;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'application': application,
    'bindings': bindings.map((k, v) => MapEntry(k, v.toJson())),
    'combinations': combinations.map((c) => c.toJson()).toList(),
  };
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'],
    name: j['name'],
    application: j['application'] ?? '',
    bindings: (j['bindings'] as Map).map(
      (k, v) => MapEntry(
        k as String,
        ControlBinding.fromJson(Map<String, dynamic>.from(v)),
      ),
    ),
    combinations: (j['combinations'] as List? ?? [])
        .map((c) => Combination.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
  );
}
