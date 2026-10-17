part of 'clave_login_card.dart';

final class _ClaveLoginCardState extends State<ClaveLoginCard> {
  ClaveLoaLevel _loa = ClaveLoaLevel.low;

  @override
  Widget build(BuildContext context) {
    final methods = ClaveAuthMethod.values.where(
      (method) => method != ClaveAuthMethod.claveMovil,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ExampleClaveConfig.readiness,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        DropdownButtonFormField(
          initialValue: _loa,
          decoration: const InputDecoration(labelText: 'Level of assurance'),
          items: [
            for (final level in ClaveLoaLevel.values)
              DropdownMenuItem(value: level, child: Text(level.name)),
          ],
          onChanged: (level) => setState(() => _loa = level ?? _loa),
        ),
        const SizedBox(height: 8),
        for (final method in methods.where((m) => m.supportsLoa(_loa)))
          ActionButton(
            controller: widget.controller,
            icon: method.icon,
            label: 'Sign in with ${method.name}',
            hint: method.idpValue,
            working: 'Opening the Cl@ve browser',
            action: () => widget.actions.login(method, _loa),
          ),
        for (final method in methods.where((m) => !m.supportsLoa(_loa)))
          Text(
            '${method.name} cannot reach ${_loa.name}, so it is not offered.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}
