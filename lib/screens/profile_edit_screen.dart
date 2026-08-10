import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/player.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/player_avatar.dart';
import '../widgets/ui_bits.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({this.playerId, super.key});

  final String? playerId;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _location;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;
  late final TextEditingController _customBowling;
  late final TextEditingController _avatarUrl;
  late final TextEditingController _avatarName;
  late BattingStyle _battingStyle;
  late Set<String> _bowlingStyles;
  late DateTime? _dateOfBirth;
  late AvatarSource _avatarSource;
  late int _avatarPreset;
  late Map<String, ProfileVisibility> _visibility;
  late Map<String, Set<String>> _audiences;
  late List<PrivateAvatar> _privateAvatars;
  bool _busy = false;

  Player get _player {
    final store = AppScope.read(context);
    return store.playerById(widget.playerId) ?? store.activePlayer!;
  }

  @override
  void initState() {
    super.initState();
    final store = AppScope.read(context);
    final player = store.playerById(widget.playerId) ?? store.activePlayer!;
    _name = TextEditingController(text: player.name);
    _bio = TextEditingController(text: player.bio);
    _phone = TextEditingController(text: player.phoneNumber);
    _whatsapp = TextEditingController(text: player.whatsappNumber);
    _location = TextEditingController(text: player.location);
    _instagram = TextEditingController(text: player.instagramHandle);
    _facebook = TextEditingController(text: player.facebookUrl);
    _customBowling = TextEditingController(text: player.customBowlingStyle);
    _avatarUrl = TextEditingController(text: player.avatarUrl);
    _avatarName = TextEditingController();
    _battingStyle = player.battingStyle;
    _bowlingStyles = player.bowlingStyles.toSet();
    _dateOfBirth = player.dateOfBirth;
    _avatarSource = player.avatarSource;
    _avatarPreset = player.avatarPreset;
    _visibility = Map<String, ProfileVisibility>.from(
      player.contactVisibility,
    );
    _audiences = player.contactAudienceIds.map(
      (key, value) => MapEntry(key, value.toSet()),
    );
    _privateAvatars = player.privateAvatars
        .map(
          (value) => PrivateAvatar(
            id: value.id,
            name: value.name,
            url: value.url,
            createdAt: value.createdAt,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _bio,
      _phone,
      _whatsapp,
      _location,
      _instagram,
      _facebook,
      _customBowling,
      _avatarUrl,
      _avatarName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (value != null) setState(() => _dateOfBirth = value);
  }

  void _addPrivateAvatar() {
    final value = _avatarUrl.text.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _message('Enter a complete HTTPS image URL.');
      return;
    }
    setState(() {
      final existing = _privateAvatars.where((avatar) => avatar.url == value);
      if (existing.isEmpty) {
        _privateAvatars.add(
          PrivateAvatar(
            id: 'avatar-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
            name: _avatarName.text.trim().isEmpty
                ? 'Custom avatar ${_privateAvatars.length + 1}'
                : _avatarName.text.trim(),
            url: value,
            createdAt: DateTime.now(),
          ),
        );
      }
      _avatarSource = AvatarSource.customUrl;
    });
    _avatarName.clear();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final player = _player;
      player
        ..name = _name.text
        ..bio = _bio.text
        ..phoneNumber = _phone.text
        ..whatsappNumber = _whatsapp.text
        ..location = _location.text
        ..instagramHandle = _instagram.text
        ..facebookUrl = _facebook.text
        ..dateOfBirth = _dateOfBirth
        ..battingStyle = _battingStyle
        ..customBowlingStyle = _customBowling.text
        ..avatarSource = _avatarSource
        ..avatarPreset = _avatarPreset
        ..avatarUrl = _avatarSource == AvatarSource.customUrl
            ? _avatarUrl.text.trim()
            : null;
      player.bowlingStyles
        ..clear()
        ..addAll(_bowlingStyles);
      player.privateAvatars
        ..clear()
        ..addAll(_privateAvatars);
      player.contactVisibility
        ..clear()
        ..addAll(_visibility);
      player.contactAudienceIds
        ..clear()
        ..addAll(
          _audiences.map((key, value) => MapEntry(key, value.toList())),
        );
      await AppScope.read(context).savePlayerProfile(player);
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final player = store.playerById(widget.playerId) ?? store.activePlayer!;
    final friends = player.friendIds
        .map(store.playerById)
        .whereType<Player>()
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playerId == null ? 'Edit profile' : 'Edit player'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            const ScreenTitle(
              title: 'Your cricket identity',
              subtitle: 'Edit every field. Sensitive information stays private by default.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Player name'),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter at least two characters'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              maxLength: 160,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'About you',
                hintText: 'Street-cricket finisher 🏏 Calm under pressure 😎',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.cake_outlined),
              title: Text(
                _dateOfBirth == null
                    ? 'Add date of birth'
                    : _dateLabel(_dateOfBirth!),
              ),
              subtitle: Text(
                _dateOfBirth == null
                    ? 'Age will calculate automatically'
                    : 'Age ${player.age ?? ''}',
              ),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: _pickDate,
            ),
            const SizedBox(height: 20),
            const SectionLabel('Playing style'),
            const SizedBox(height: 10),
            SegmentedButton<BattingStyle>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: BattingStyle.rightHanded,
                  label: Text('Right bat'),
                ),
                ButtonSegment(
                  value: BattingStyle.leftHanded,
                  label: Text('Left bat'),
                ),
              ],
              selected: {_battingStyle},
              onSelectionChanged: (value) =>
                  setState(() => _battingStyle = value.single),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final style in builtInBowlingStyles)
                  FilterChip(
                    label: Text(style),
                    selected: _bowlingStyles.contains(style),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _bowlingStyles.add(style);
                      } else {
                        _bowlingStyles.remove(style);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customBowling,
              decoration: const InputDecoration(
                labelText: 'Custom bowling style (optional)',
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Avatar'),
            const SizedBox(height: 10),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final number = index + 1;
                  final selected =
                      _avatarSource == AvatarSource.preset &&
                      _avatarPreset == number;
                  return InkWell(
                    borderRadius: BorderRadius.circular(38),
                    onTap: () => setState(() {
                      _avatarSource = AvatarSource.preset;
                      _avatarPreset = number;
                    }),
                    child: Container(
                      width: 76,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.greenDark
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/avatars/avatar_$number.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _avatarName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Custom avatar name (optional)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _avatarUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Private custom avatar URL',
                helperText: 'HTTPS only. Visible only from your private profile data.',
                suffixIcon: IconButton(
                  onPressed: _addPrivateAvatar,
                  icon: const Icon(Icons.add_link_rounded),
                ),
              ),
            ),
            if (_privateAvatars.isNotEmpty)
              Wrap(
                spacing: 6,
                children: _privateAvatars
                    .map(
                      (avatar) => InputChip(
                        label: Text(
                          '${avatar.name} • ${avatar.id}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => setState(() {
                          _avatarUrl.text = avatar.url;
                          _avatarSource = AvatarSource.customUrl;
                        }),
                        onDeleted: () => setState(() {
                          _privateAvatars.remove(avatar);
                          if (_avatarUrl.text == avatar.url) {
                            _avatarUrl.clear();
                            _avatarSource = AvatarSource.preset;
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 24),
            const SectionLabel('Social links'),
            const SizedBox(height: 10),
            TextField(
              controller: _instagram,
              decoration: const InputDecoration(
                labelText: 'Instagram username or profile URL',
                prefixIcon: Icon(Icons.camera_alt_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _facebook,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Facebook profile URL',
                prefixIcon: Icon(Icons.facebook_rounded),
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Contact & privacy'),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
              child: Text(
                'Login email is managed in Account settings and is not asked again in the player profile.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
            _ContactEditor(
              field: 'phone',
              label: 'Phone number',
              icon: Icons.phone_outlined,
              controller: _phone,
              visibility: _visibility['phone'] ?? ProfileVisibility.onlyMe,
              selectedIds: _audiences['phone'] ?? <String>{},
              friends: friends,
              onVisibilityChanged: (value) =>
                  setState(() => _visibility['phone'] = value),
              onSelectedChanged: (value) =>
                  setState(() => _audiences['phone'] = value),
            ),
            _ContactEditor(
              field: 'whatsapp',
              label: 'WhatsApp',
              icon: Icons.chat_outlined,
              controller: _whatsapp,
              visibility:
                  _visibility['whatsapp'] ?? ProfileVisibility.onlyMe,
              selectedIds: _audiences['whatsapp'] ?? <String>{},
              friends: friends,
              onVisibilityChanged: (value) =>
                  setState(() => _visibility['whatsapp'] = value),
              onSelectedChanged: (value) =>
                  setState(() => _audiences['whatsapp'] = value),
            ),
            _ContactEditor(
              field: 'location',
              label: 'Place',
              icon: Icons.location_on_outlined,
              controller: _location,
              visibility:
                  _visibility['location'] ?? ProfileVisibility.onlyMe,
              selectedIds: _audiences['location'] ?? <String>{},
              friends: friends,
              onVisibilityChanged: (value) =>
                  setState(() => _visibility['location'] = value),
              onSelectedChanged: (value) =>
                  setState(() => _audiences['location'] = value),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('Save profile'),
        ),
      ),
    );
  }
}

class _ContactEditor extends StatelessWidget {
  const _ContactEditor({
    required this.field,
    required this.label,
    required this.icon,
    required this.controller,
    required this.visibility,
    required this.selectedIds,
    required this.friends,
    required this.onVisibilityChanged,
    required this.onSelectedChanged,
  });

  final String field;
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final ProfileVisibility visibility;
  final Set<String> selectedIds;
  final List<Player> friends;
  final ValueChanged<ProfileVisibility> onVisibilityChanged;
  final ValueChanged<Set<String>> onSelectedChanged;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: controller,
            keyboardType: field == 'location'
                ? TextInputType.streetAddress
                : TextInputType.phone,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<ProfileVisibility>(
            initialValue: visibility,
            decoration: const InputDecoration(
              labelText: 'Who can see this?',
              prefixIcon: Icon(Icons.visibility_outlined),
            ),
            items: ProfileVisibility.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onVisibilityChanged(value);
            },
          ),
          if (visibility == ProfileVisibility.selectedFriends ||
              visibility == ProfileVisibility.everyoneExceptSelected) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                visibility == ProfileVisibility.selectedFriends
                    ? 'Allowed friends'
                    : 'Hidden from',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 6),
            if (friends.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add friends first.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              Wrap(
                spacing: 6,
                children: friends
                    .map(
                      (friend) => FilterChip(
                        avatar: PlayerAvatar(player: friend, radius: 10),
                        label: Text(friend.name),
                        selected: selectedIds.contains(friend.id),
                        onSelected: (selected) {
                          final next = Set<String>.from(selectedIds);
                          selected ? next.add(friend.id) : next.remove(friend.id);
                          onSelectedChanged(next);
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        ],
      ),
    ),
  );
}
