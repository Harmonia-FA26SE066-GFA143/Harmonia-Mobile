import 'dart:async';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../core/errors/error_messages.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../lookups/data/lookup_dto.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../../practice/data/practice_models.dart';
import '../../practice/data/practice_repository.dart';
import '../../profile/data/profile_models.dart';
import '../../profile/data/profile_repository.dart';
import '../data/music_dto.dart';
import 'music_library_notifier.dart';
import 'music_tile_icon.dart';
import 'reference_audio_panel.dart';

final _librarySeasons = FutureProvider.autoDispose(
  (ref) => ref.watch(lookupsApiServiceProvider).getLiturgicalSeasons(),
);

class MusicLibraryScreen extends ConsumerStatefulWidget {
  const MusicLibraryScreen({super.key});

  @override
  ConsumerState<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends ConsumerState<MusicLibraryScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _searchOpen = false;
  String? _searchValidationError;
  bool _showSongFilters = false;
  Future<_SongFilterOptions>? _filterOptionsFuture;

  @override
  void initState() {
    super.initState();
    final initialKeyword = ref.read(musicLibraryProvider).keyword;
    _search.text = initialKeyword;
    _searchOpen = initialKeyword.isNotEmpty;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<_SongFilterOptions> _loadSongFilterOptions() async {
    final service = ref.read(lookupsApiServiceProvider);
    final values = await Future.wait<Object>([
      service.getLiturgicalSeasons(),
      service.getMassTypes(),
      service.getCeremonyTypes(),
      service.getSongThemes(),
      service.getLiturgicalSlots(),
      service.getSkills(),
    ]);
    return _SongFilterOptions(
      seasons: values[0] as List<LiturgicalSeasonDto>,
      massTypes: values[1] as List<LookupItemDto>,
      ceremonyTypes: values[2] as List<LookupItemDto>,
      themes: values[3] as List<LookupItemDto>,
      slots: values[4] as List<LiturgicalSlotDto>,
      skills: values[5] as List<SkillDto>,
    );
  }

  void _toggleSongFilters() {
    setState(() {
      _showSongFilters = !_showSongFilters;
      if (_showSongFilters) {
        _filterOptionsFuture ??= _loadSongFilterOptions();
      }
    });
  }

  Widget _buildSongFilters(
    MusicLibraryState state,
    MusicLibraryNotifier notifier,
  ) {
    return FutureBuilder<_SongFilterOptions>(
      future: _filterOptionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(ErrorMessages.forException(snapshot.error)),
                    ),
                    IconButton(
                      tooltip: 'Tải lại bộ lọc',
                      onPressed: () => setState(
                        () => _filterOptionsFuture = _loadSongFilterOptions(),
                      ),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final options = snapshot.requireData;
        final lookupChoices = <String, List<_SongFilterChoice>>{
          'season': [
            for (final item in options.seasons)
              _SongFilterChoice(item.id, item.name),
          ],
          'mass': [
            for (final item in options.massTypes)
              _SongFilterChoice(item.id, item.name),
          ],
          'ceremony': [
            for (final item in options.ceremonyTypes)
              _SongFilterChoice(item.id, item.name),
          ],
          'theme': [
            for (final item in options.themes)
              _SongFilterChoice(item.id, item.name),
          ],
          'slot': [
            for (final item in options.slots)
              _SongFilterChoice(item.id, item.name),
          ],
          'skill': [
            for (final item in options.skills)
              _SongFilterChoice(item.id, item.name),
          ],
          'missingMaterial': [
            for (final item in MaterialType.filterOptions)
              _SongFilterChoice(item.wireName, item.label),
          ],
        };

        void apply({
          String? seasonId,
          String? massTypeId,
          String? ceremonyTypeId,
          String? songThemeId,
          String? liturgicalSlotId,
          String? skillId,
          bool? isClassified,
          MaterialType? missingMaterialType,
        }) {
          notifier.refresh(
            keyword: _search.text,
            materialsTab: false,
            liturgicalSeasonId: seasonId,
            massTypeId: massTypeId,
            ceremonyTypeId: ceremonyTypeId,
            songThemeId: songThemeId,
            liturgicalSlotId: liturgicalSlotId,
            skillId: skillId,
            isClassified: isClassified,
            missingMaterialType: missingMaterialType,
            replaceFilters: true,
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            color: AppColors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildLookupFilter(
                        width: width,
                        label: 'Mùa phụng vụ',
                        value: state.liturgicalSeasonId,
                        choices: lookupChoices['season']!,
                        onChanged: (value) => apply(
                          seasonId: value,
                          massTypeId: state.massTypeId,
                          ceremonyTypeId: state.ceremonyTypeId,
                          songThemeId: state.songThemeId,
                          liturgicalSlotId: state.liturgicalSlotId,
                          skillId: state.skillId,
                          isClassified: state.isClassified,
                          missingMaterialType: state.missingMaterialType,
                        ),
                      ),
                      _buildLookupFilter(
                        width: width,
                        label: 'Loại Thánh lễ',
                        value: state.massTypeId,
                        choices: lookupChoices['mass']!,
                        onChanged: (value) => apply(
                          seasonId: state.liturgicalSeasonId,
                          massTypeId: value,
                          ceremonyTypeId: state.ceremonyTypeId,
                          songThemeId: state.songThemeId,
                          liturgicalSlotId: state.liturgicalSlotId,
                          skillId: state.skillId,
                          isClassified: state.isClassified,
                          missingMaterialType: state.missingMaterialType,
                        ),
                      ),
                      _buildLookupFilter(
                        width: width,
                        label: 'Loại nghi thức',
                        value: state.ceremonyTypeId,
                        choices: lookupChoices['ceremony']!,
                        onChanged: (value) => apply(
                          seasonId: state.liturgicalSeasonId,
                          massTypeId: state.massTypeId,
                          ceremonyTypeId: value,
                          songThemeId: state.songThemeId,
                          liturgicalSlotId: state.liturgicalSlotId,
                          skillId: state.skillId,
                          isClassified: state.isClassified,
                          missingMaterialType: state.missingMaterialType,
                        ),
                      ),
                      _buildLookupFilter(
                        width: width,
                        label: 'Chủ đề',
                        value: state.songThemeId,
                        choices: lookupChoices['theme']!,
                        onChanged: (value) => apply(
                          seasonId: state.liturgicalSeasonId,
                          massTypeId: state.massTypeId,
                          ceremonyTypeId: state.ceremonyTypeId,
                          songThemeId: value,
                          liturgicalSlotId: state.liturgicalSlotId,
                          skillId: state.skillId,
                          isClassified: state.isClassified,
                          missingMaterialType: state.missingMaterialType,
                        ),
                      ),
                      _buildLookupFilter(
                        width: width,
                        label: 'Phần phụng vụ',
                        value: state.liturgicalSlotId,
                        choices: lookupChoices['slot']!,
                        onChanged: (value) => apply(
                          seasonId: state.liturgicalSeasonId,
                          massTypeId: state.massTypeId,
                          ceremonyTypeId: state.ceremonyTypeId,
                          songThemeId: state.songThemeId,
                          liturgicalSlotId: value,
                          skillId: state.skillId,
                          isClassified: state.isClassified,
                          missingMaterialType: state.missingMaterialType,
                        ),
                      ),
                      _buildLookupFilter(
                        width: width,
                        label: 'Bè giọng hoặc nhạc cụ',
                        value: state.skillId,
                        choices: lookupChoices['skill']!,
                        onChanged: (value) => apply(
                          seasonId: state.liturgicalSeasonId,
                          massTypeId: state.massTypeId,
                          ceremonyTypeId: state.ceremonyTypeId,
                          songThemeId: state.songThemeId,
                          liturgicalSlotId: state.liturgicalSlotId,
                          skillId: value,
                          isClassified: state.isClassified,
                          missingMaterialType: state.missingMaterialType,
                        ),
                      ),
                      _buildClassificationFilter(
                        width: width,
                        value: state.isClassified,
                        onChanged: (value) => apply(
                          seasonId: state.liturgicalSeasonId,
                          massTypeId: state.massTypeId,
                          ceremonyTypeId: state.ceremonyTypeId,
                          songThemeId: state.songThemeId,
                          liturgicalSlotId: state.liturgicalSlotId,
                          skillId: state.skillId,
                          isClassified: value,
                          missingMaterialType: state.missingMaterialType,
                        ),
                      ),
                      _buildLookupFilter(
                        width: width,
                        label: 'Thiếu tài liệu',
                        value: state.missingMaterialType?.wireName,
                        choices: lookupChoices['missingMaterial']!,
                        onChanged: (value) => apply(
                          seasonId: state.liturgicalSeasonId,
                          massTypeId: state.massTypeId,
                          ceremonyTypeId: state.ceremonyTypeId,
                          songThemeId: state.songThemeId,
                          liturgicalSlotId: state.liturgicalSlotId,
                          skillId: state.skillId,
                          isClassified: state.isClassified,
                          missingMaterialType: MaterialType.filterOptions
                              .cast<MaterialType?>()
                              .firstWhere(
                                (type) => type?.wireName == value,
                                orElse: () => null,
                              ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLookupFilter({
    required double width,
    required String label,
    required String? value,
    required List<_SongFilterChoice> choices,
    required ValueChanged<String?> onChanged,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey((label, value)),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Tất cả')),
        for (final choice in choices)
          DropdownMenuItem<String>(
            value: choice.id,
            child: Text(choice.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );

  Widget _buildClassificationFilter({
    required double width,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<bool>(
      key: ValueKey(('classification', value)),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Phân loại'),
      items: const [
        DropdownMenuItem<bool>(value: null, child: Text('Tất cả')),
        DropdownMenuItem<bool>(value: true, child: Text('Đã phân loại')),
        DropdownMenuItem<bool>(value: false, child: Text('Chưa phân loại')),
      ],
      onChanged: onChanged,
    ),
  );

  void _switchTab(bool materialsTab, MusicLibraryNotifier notifier) {
    if (ref.read(musicLibraryProvider).materialsTab == materialsTab) return;
    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    final trimmed = _search.text.trim();
    setState(() {
      _showSongFilters = false;
      if (_search.text.isNotEmpty && trimmed.isEmpty) {
        _searchValidationError =
            'Vui lòng nhập ít nhất 1 ký tự (không chỉ khoảng trắng).';
      } else {
        _searchValidationError = null;
      }
    });
    notifier.refresh(materialsTab: materialsTab, keyword: trimmed);
  }

  void _openSearch() {
    setState(() {
      _searchOpen = true;
      _searchValidationError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _onSearchChanged(String raw, MusicLibraryNotifier notifier) {
    _searchDebounce?.cancel();
    final trimmed = raw.trim();
    if (raw.isEmpty) {
      setState(() => _searchValidationError = null);
      if (ref.read(musicLibraryProvider).keyword.isNotEmpty) {
        notifier.refresh(keyword: '');
      }
      return;
    }
    if (trimmed.isEmpty) {
      setState(
        () => _searchValidationError =
            'Vui lòng nhập ít nhất 1 ký tự (không chỉ khoảng trắng).',
      );
      return;
    }
    setState(() => _searchValidationError = null);
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      notifier.refresh(keyword: trimmed);
    });
  }

  void _submitSearch(MusicLibraryNotifier notifier) {
    _searchDebounce?.cancel();
    final trimmed = _search.text.trim();
    if (trimmed.isEmpty) {
      setState(
        () => _searchValidationError = _search.text.isNotEmpty
            ? 'Vui lòng nhập ít nhất 1 ký tự (không chỉ khoảng trắng).'
            : 'Vui lòng nhập ít nhất 1 ký tự để tìm kiếm.',
      );
      _searchFocus.requestFocus();
      return;
    }
    setState(() => _searchValidationError = null);
    FocusScope.of(context).unfocus();
    notifier.refresh(keyword: trimmed);
  }

  void _clearSearch(MusicLibraryNotifier notifier, {bool close = false}) {
    _searchDebounce?.cancel();
    _search.clear();
    setState(() {
      _searchValidationError = null;
      if (close) _searchOpen = false;
    });
    if (close) {
      FocusScope.of(context).unfocus();
    } else {
      _searchFocus.requestFocus();
    }
    if (ref.read(musicLibraryProvider).keyword.isNotEmpty) {
      notifier.refresh(keyword: '');
    }
  }

  Widget _headerSearchField(
    MusicLibraryNotifier notifier, {
    required bool materials,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: 40,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _search,
        builder: (context, value, _) => TextField(
          key: const ValueKey('library-header-search'),
          controller: _search,
          focusNode: _searchFocus,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: Color(0xFF111C2D), fontSize: 14),
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          onChanged: (raw) => _onSearchChanged(raw, notifier),
          onSubmitted: (_) => _submitSearch(notifier),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: materials
                ? 'Tìm tài liệu (≥1 ký tự)…'
                : 'Tìm bài hát, tác giả (≥1 ký tự)…',
            hintStyle: const TextStyle(color: Color(0xFF76767E), fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: MemberChoirStyle.wine,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Xóa từ khóa',
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF76767E),
                    ),
                    onPressed: () => _clearSearch(notifier),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 34,
              minHeight: 34,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
          ),
        ),
      ),
    );
  }

  Widget _seasonChips(MusicLibraryState state, MusicLibraryNotifier notifier) {
    final seasons = ref.watch(_librarySeasons).value ?? [];
    void select(String? id) => notifier.refresh(
      liturgicalSeasonId: id,
      massTypeId: state.massTypeId,
      ceremonyTypeId: state.ceremonyTypeId,
      songThemeId: state.songThemeId,
      liturgicalSlotId: state.liturgicalSlotId,
      skillId: state.skillId,
      isClassified: state.isClassified,
      missingMaterialType: state.missingMaterialType,
      replaceFilters: true,
    );
    return _filterRail(
      label: 'Mùa phụng vụ',
      chips: [
        _typeFilterChip(
          label: 'Tất cả mùa',
          selected: state.liturgicalSeasonId == null,
          onSelected: (_) => select(null),
        ),
        for (final season in seasons)
          _typeFilterChip(
            label: season.name,
            selected: state.liturgicalSeasonId == season.id,
            onSelected: (selected) => select(selected ? season.id : null),
          ),
      ],
    );
  }

  Widget _materialFilters(
    MusicLibraryState state,
    MusicLibraryNotifier notifier,
  ) {
    void apply({MaterialType? type, LearningStatus? status}) =>
        notifier.refresh(
          materialType: type,
          learningStatus: status,
          replaceFilters: true,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterRail(
          label: 'Loại tài liệu',
          chips: [
            _typeFilterChip(
              label: 'Tất cả loại',
              selected: state.materialType == null,
              onSelected: (_) => apply(status: state.learningStatus),
            ),
            for (final type in MaterialType.filterOptions)
              _typeFilterChip(
                label: type.label,
                selected: state.materialType == type,
                onSelected: (selected) => apply(
                  type: selected ? type : null,
                  status: state.learningStatus,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _ProgressFilterTabs(
          selected: state.learningStatus,
          onSelect: (status) => apply(type: state.materialType, status: status),
        ),
      ],
    );
  }

  Widget _typeFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
    showCheckmark: false,
    backgroundColor: Colors.white,
    selectedColor: MemberChoirStyle.wine,
    side: BorderSide(
      color: selected ? MemberChoirStyle.wine : const Color(0xFFE6E1D8),
    ),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    labelStyle: TextStyle(
      fontSize: 12.5,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      color: selected ? Colors.white : const Color(0xFF45464D),
    ),
  );

  Widget _filterRail({required String label, required List<Widget> chips}) =>
      Semantics(
        label: label,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(spacing: 8, children: chips),
        ),
      );

  Widget _songCard(
    BuildContext context,
    SongDto song, {
    required bool assigned,
  }) {
    final subtitle = [
      if (song.composer?.trim().isNotEmpty == true) song.composer!,
      if (song.musicalKey?.trim().isNotEmpty == true) 'Cung ${song.musicalKey}',
      if (song.interactiveScoreCount case final count?)
        '$count bản nhạc tương tác',
    ].join(' • ');
    return StitchEntrance(
      key: ValueKey(song.id),
      child: Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(top: 2, bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE6E1D8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          leading: assigned
              ? const CircleAvatar(
                  backgroundColor: MemberChoirStyle.wine,
                  foregroundColor: MemberChoirStyle.softGold,
                  child: Icon(Icons.music_note_rounded),
                )
              : const MusicTileIcon(
                  materialType: MaterialType.sampleAudio,
                  size: 46,
                ),
          title: Text(
            song.title,
            style: AppTypography.titleMedium.copyWith(
              color: const Color(0xFF111C2D),
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: const Color(0xFF45464D),
                  ),
                ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: MemberChoirStyle.wine,
          ),
          onTap: () =>
              context.push('/song-detail/${Uri.encodeComponent(song.id)}'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(musicLibraryProvider.select((s) => s.keyword), (
      _,
      next,
    ) {
      if (!_searchFocus.hasFocus && _search.text != next) {
        _search.text = next;
      }
      if (next.isNotEmpty && !_searchOpen) {
        setState(() => _searchOpen = true);
      }
    });

    final state = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);
    final materials = state.materialsTab;
    final searchActive = _searchOpen || state.keyword.isNotEmpty;
    final choirName = ref
        .watch(publicAppSettingsProvider)
        .asData
        ?.value
        .choirName
        .trim();
    final practiceItems =
        (materials && state.materials.isNotEmpty) ||
            (!materials && state.songs.isNotEmpty)
        ? ref.watch(practiceListNotifierProvider).asData?.value.items ??
              const <PracticeAssignment>[]
        : const <PracticeAssignment>[];
    final assignedIds = !materials && state.songs.isNotEmpty
        ? practiceItems.map((item) => item.songId).nonNulls.toSet()
        : const <String>{};
    final assigned = state.songs.where((song) => assignedIds.contains(song.id));
    final catalog = state.songs.where((song) => !assignedIds.contains(song.id));
    final approvedSkills = materials
        ? (ref
                  .watch(currentMemberSkillsProvider)
                  .asData
                  ?.value
                  .where(
                    (s) =>
                        s.status == SkillApprovalStatus.approved &&
                        s.name.trim().isNotEmpty,
                  )
                  .map((s) => s.name.trim())
                  .toSet()
                  .toList() ??
              const <String>[])
        : const <String>[];
    final events = !state.materialsTab && state.songs.isNotEmpty
        ? ref.watch(calendarNotifierProvider).value
        : null;
    final nextEvent = events
        ?.where(
          (event) =>
              event.date.isAfter(DateTime.now()) ||
              DateUtils.isSameDay(event.date, DateTime.now()),
        )
        .firstOrNull;

    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );

    final listView = ListView(
      key: ValueKey(materials),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (materials)
          MemberChoirArt(
            artwork: MemberChoirArtwork.materials,
            height: 152,
            alignment: const Alignment(0, 0.35),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x281B0A0F), Color(0xB8461522), Color(0xF06D2636)],
              stops: [0.0, 0.55, 1.0],
            ),
            caption: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                if (approvedSkills.isNotEmpty)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x992D0D15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x66F7E6B5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFECE57),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'Bè: ${approvedSkills.join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                color: const Color(0xFFF7E6B5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(
                  'Tài liệu học tập',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontFamily: MemberChoirStyle.displayFont,
                  ),
                ),
                Text(
                  choirName != null && choirName.isNotEmpty
                      ? 'Ca viên • $choirName'
                      : 'Bản phổ, audio mẫu & bài tập luyện hát',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: const Color(0xFFF3E4DE),
                  ),
                ),
              ],
            ),
          )
        else
          MemberChoirArt(
            artwork: MemberChoirArtwork.library,
            height: 164,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x281B0A0F), Color(0xB8461522), Color(0xF06D2636)],
              stops: [0.0, 0.55, 1.0],
            ),
            caption: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  'Bài hát và bản phổ',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontFamily: MemberChoirStyle.displayFont,
                  ),
                ),
                Text(
                  choirName != null && choirName.isNotEmpty
                      ? 'Ca viên • $choirName'
                      : 'Kho thánh ca & bản phổ phụng vụ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: const Color(0xFFF3E4DE),
                  ),
                ),
              ],
            ),
          ),
        if (materials && state.materials.isNotEmpty)
          _LibraryOverviewStrip.materials(
            items: state.materials,
            totalCount: state.totalCount,
            hasMore: state.hasMore,
          )
        else if (!materials && state.songs.isNotEmpty)
          _LibraryOverviewStrip.songs(
            songs: state.songs,
            assignedCount: assigned.length,
            totalCount: state.totalCount,
            hasMore: state.hasMore,
          ),
        const SizedBox(height: 12),
        if (!materials) ...[
          pad(_seasonChips(state, notifier)),
          if (_showSongFilters) _buildSongFilters(state, notifier),
          if (state.keyword.isNotEmpty || state.hasSongFilters)
            pad(
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _search.clear();
                    setState(() {
                      _searchValidationError = null;
                      _searchOpen = false;
                    });
                    FocusScope.of(context).unfocus();
                    notifier.refresh(keyword: '', replaceFilters: true);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: MemberChoirStyle.wine,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Đặt lại'),
                ),
              ),
            ),
        ] else ...[
          pad(_materialFilters(state, notifier)),
          if (state.keyword.isNotEmpty ||
              state.materialType != null ||
              state.learningStatus != null)
            pad(
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _search.clear();
                    setState(() {
                      _searchValidationError = null;
                      _searchOpen = false;
                    });
                    FocusScope.of(context).unfocus();
                    notifier.refresh(keyword: '', replaceFilters: true);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: MemberChoirStyle.wine,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Đặt lại'),
                ),
              ),
            ),
        ],
        if (state.loading)
          pad(
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                color: MemberChoirStyle.wine,
                backgroundColor: Color(0xFFE6E1D8),
              ),
            ),
          ),
        if (state.error case final error?)
          pad(
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE6E1D8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(error, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: state.loading || state.loadingMore
                            ? null
                            : () => state.hasMore
                                  ? notifier.loadMore()
                                  : notifier.refresh(),
                        style: TextButton.styleFrom(
                          foregroundColor: MemberChoirStyle.wine,
                        ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (!state.loading && state.error == null && state.isEmpty)
          pad(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 42,
                    color: AppColors.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.keyword.isNotEmpty ||
                            state.hasSongFilters ||
                            state.materialType != null ||
                            state.learningStatus != null
                        ? state.materialsTab
                              ? 'Không tìm thấy tài liệu phù hợp'
                              : 'Không có kết quả phù hợp'
                        : state.materialsTab
                        ? 'Bạn chưa có tài liệu học'
                        : 'Thư viện chưa có bài hát',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium,
                  ),
                  if (state.keyword.isNotEmpty ||
                      state.hasSongFilters ||
                      state.materialType != null ||
                      state.learningStatus != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Vui lòng điều chỉnh bộ lọc hoặc từ khóa tìm kiếm.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (!materials) ...[
          if (assigned.isNotEmpty) ...[
            pad(const _LibrarySectionTitle('Bài hát có bài tập')),
            for (final song in assigned)
              pad(_songCard(context, song, assigned: true)),
          ],
          if (catalog.isNotEmpty) ...[
            pad(const _LibrarySectionTitle('Thánh ca phụng vụ')),
            for (final song in catalog)
              pad(_songCard(context, song, assigned: false)),
          ],
        ] else ...[
          const SizedBox(height: 8),
          for (final material in state.materials)
            pad(
              StitchEntrance(
                key: ValueKey(material.id),
                child: _LibraryMaterialCard(
                  material: material,
                  assignment: _matchAssignment(material, practiceItems),
                  onOpen: () async {
                    await context.push(
                      Uri(
                        pathSegments: ['', 'music-material', material.id],
                        queryParameters: {'songId': material.songId},
                      ).toString(),
                    );
                    if (mounted) await notifier.refresh();
                  },
                  onOpenInteractiveScore: () async {
                    await context.push(
                      '/interactive-score/${Uri.encodeComponent(material.id)}',
                    );
                    if (mounted) await notifier.refresh();
                  },
                  onOpenPractice: (assignmentId) async {
                    await context.push(
                      '/practice-detail/${Uri.encodeComponent(assignmentId)}',
                    );
                    if (mounted) await notifier.refresh();
                  },
                ),
              ),
            ),
        ],
        if (state.hasMore)
          pad(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: OutlinedButton(
                onPressed: state.loading || state.loadingMore
                    ? null
                    : notifier.loadMore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MemberChoirStyle.wine,
                  side: const BorderSide(color: MemberChoirStyle.wine),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.loadingMore
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MemberChoirStyle.wine,
                        ),
                      )
                    : const Text('Tải thêm'),
              ),
            ),
          ),
        if (nextEvent != null)
          pad(
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Card(
                color: const Color(0xFF182239),
                child: ListTile(
                  leading: const Icon(
                    Icons.queue_music_rounded,
                    color: Color(0xFFFFD369),
                  ),
                  title: const Text(
                    'Phụng vụ sắp tới',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    nextEvent.title,
                    style: const TextStyle(color: Color(0xFFD2DAEB)),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward,
                    color: Color(0xFFFFD369),
                  ),
                  onTap: () => context.push(
                    '/event-detail/${Uri.encodeComponent(nextEvent.id)}',
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final scaffold = Scaffold(
      backgroundColor: MemberChoirStyle.paper,
      appBar: AppPageHeader(
        gradient: MemberChoirStyle.header,
        titleFontFamily: MemberChoirStyle.displayFont,
        title: searchActive
            ? _headerSearchField(notifier, materials: materials)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (choirName != null && choirName.isNotEmpty) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC59B27),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            choirName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: const Color(0xFFF7E6B5),
                              fontSize: 10.5,
                              letterSpacing: 0.9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                  ],
                  Text(
                    materials ? 'Tài liệu học của tôi' : 'Thư viện thánh ca',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          if (!materials)
            IconButton(
              tooltip: 'Bộ lọc',
              icon: Badge(
                isLabelVisible: state.hasSongFilters,
                backgroundColor: const Color(0xFFFFD36D),
                child: Icon(
                  _showSongFilters
                      ? Icons.filter_alt_off_outlined
                      : Icons.tune_rounded,
                ),
              ),
              onPressed: _toggleSongFilters,
            ),
          if (searchActive)
            IconButton(
              tooltip: 'Đóng tìm kiếm',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _clearSearch(notifier, close: true),
            )
          else
            IconButton(
              tooltip: 'Tìm kiếm',
              icon: const Icon(Icons.search_rounded),
              onPressed: _openSearch,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            if (_searchValidationError case final errorText?)
              Container(
                width: double.infinity,
                color: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Color(0xFFB91C1C),
                    ),
                    Expanded(
                      child: Text(
                        errorText,
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (searchActive && _search.text.trim().isEmpty)
              Container(
                width: double.infinity,
                color: const Color(0xFF5C1E2B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  materials
                      ? 'Gõ từ 1 ký tự để hiển thị tài liệu cần tìm'
                      : 'Gõ từ 1 ký tự để hiển thị bài hát cần tìm',
                  style: AppTypography.labelSmall.copyWith(
                    color: const Color(0xFFF7E6B5),
                  ),
                ),
              ),
            _StitchHeaderTabStrip(
              materialsTab: materials,
              onSelect: (tab) => _switchTab(tab, notifier),
            ),
            Expanded(
              child: RefreshIndicator(
                color: MemberChoirStyle.wine,
                onRefresh: () => notifier.refresh(),
                child: listView,
              ),
            ),
          ],
        ),
      ),
    );
    return Theme(data: MemberChoirStyle.theme(context), child: scaffold);
  }
}

PracticeAssignment? _matchAssignment(
  MusicMaterialDetailDto material,
  List<PracticeAssignment> assignments,
) {
  for (final item in assignments) {
    if (item.materials.any((m) => m.id == material.id)) return item;
  }
  for (final item in assignments) {
    if (item.songId == material.songId) return item;
  }
  return null;
}

class _StitchHeaderTabStrip extends StatelessWidget {
  const _StitchHeaderTabStrip({
    required this.materialsTab,
    required this.onSelect,
  });

  final bool materialsTab;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF521A26),
      child: Row(
        children: [
          for (final (tabValue, label) in [
            (false, 'Kho Bài Hát Chung'),
            (true, 'Tài liệu học của tôi'),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: materialsTab == tabValue,
                child: InkWell(
                  onTap: () => onSelect(tabValue),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: materialsTab == tabValue
                              ? const Color(0xFFC59B27)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: materialsTab == tabValue
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: materialsTab == tabValue
                            ? Colors.white
                            : const Color(0xBFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressFilterTabs extends StatelessWidget {
  const _ProgressFilterTabs({required this.selected, required this.onSelect});

  final LearningStatus? selected;
  final ValueChanged<LearningStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <(LearningStatus?, String)>[
      (null, 'Tất cả tiến độ'),
      for (final status in LearningStatus.values) (status, status.label),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE6E1D8))),
      ),
      child: Semantics(
        label: 'Tiến độ',
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (status, label) in items)
                Semantics(
                  button: true,
                  selected: selected == status,
                  child: InkWell(
                    onTap: () => onSelect(status),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected == status
                                ? MemberChoirStyle.wine
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected == status
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected == status
                              ? MemberChoirStyle.wine
                              : const Color(0xFF76767E),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySectionTitle extends StatelessWidget {
  const _LibrarySectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
    child: Row(
      spacing: 8,
      children: [
        const Icon(Icons.circle, size: 10, color: MemberChoirStyle.accent),
        Flexible(
          child: Text(
            title,
            style: AppTypography.titleLarge.copyWith(
              color: MemberChoirStyle.ink,
              fontFamily: MemberChoirStyle.displayFont,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LibraryOverviewStrip extends StatelessWidget {
  const _LibraryOverviewStrip({
    required this.tiles,
    required this.hasMore,
    required this.partialNotice,
  });

  factory _LibraryOverviewStrip.materials({
    required List<MusicMaterialDetailDto> items,
    required int totalCount,
    required bool hasMore,
  }) {
    final resolvedTotal = totalCount > items.length ? totalCount : items.length;
    return _LibraryOverviewStrip(
      hasMore: hasMore,
      partialNotice: totalCount > 0
          ? 'Đang hiển thị ${items.length}/$totalCount tài liệu • Số liệu chi tiết tính trên phần đã tải'
          : 'Đang hiển thị ${items.length} tài liệu đầu • Số liệu chi tiết tính trên phần đã tải',
      tiles: [
        (
          hasMore ? (totalCount > 0 ? 'Tổng số' : 'Đã tải') : 'Tài liệu',
          hasMore
              ? (totalCount > 0 ? '$totalCount' : '${items.length}+')
              : '$resolvedTotal',
          MemberChoirStyle.wine,
        ),
        (
          'Bản phổ',
          '${items.where((item) => item.materialType == MaterialType.sheetMusic).length}',
          const Color(0xFF111C2D),
        ),
        (
          'Audio mẫu',
          '${items.where((item) => item.materialType == MaterialType.sampleAudio).length}',
          const Color(0xFF775A00),
        ),
        (
          'Đã thuộc',
          '${items.where((item) => item.learningStatus == LearningStatus.learned).length}',
          const Color(0xFF15803D),
        ),
      ],
    );
  }

  factory _LibraryOverviewStrip.songs({
    required List<SongDto> songs,
    required int assignedCount,
    required int totalCount,
    required bool hasMore,
  }) {
    final resolvedTotal = totalCount > songs.length ? totalCount : songs.length;
    final sheetSongs = songs
        .where((s) => (s.materialCounts[MaterialType.sheetMusic] ?? 0) > 0)
        .length;
    final scoreSongs = songs
        .where((s) => (s.interactiveScoreCount ?? 0) > 0)
        .length;
    return _LibraryOverviewStrip(
      hasMore: hasMore,
      partialNotice: totalCount > 0
          ? 'Đang hiển thị ${songs.length}/$totalCount bài hát • Số liệu chi tiết tính trên phần đã tải'
          : 'Đang hiển thị ${songs.length} bài hát đầu • Số liệu chi tiết tính trên phần đã tải',
      tiles: [
        (
          hasMore ? (totalCount > 0 ? 'Tổng số' : 'Đã tải') : 'Bài hát',
          hasMore
              ? (totalCount > 0 ? '$totalCount' : '${songs.length}+')
              : '$resolvedTotal',
          MemberChoirStyle.wine,
        ),
        ('Có bài tập', '$assignedCount', const Color(0xFF111C2D)),
        ('Có bản phổ', '$sheetSongs', const Color(0xFF775A00)),
        ('Tương tác', '$scoreSongs', const Color(0xFF15803D)),
      ],
    );
  }

  final List<(String label, String count, Color accent)> tiles;
  final bool hasMore;
  final String partialNotice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F5),
        border: Border(bottom: BorderSide(color: Color(0xFFE6E1D8))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          if (hasMore)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Color(0xFF76767E),
                  ),
                ),
                Expanded(
                  child: Text(
                    partialNotice,
                    style: AppTypography.labelSmall.copyWith(
                      color: const Color(0xFF76767E),
                    ),
                  ),
                ),
              ],
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  MediaQuery.textScalerOf(context).scale(13) > 19 ||
                      constraints.maxWidth < 310
                  ? 2
                  : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, count, accent) in tiles)
                    SizedBox(
                      width: width,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE6E1D8)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 2,
                            children: [
                              Text(
                                count,
                                style: AppTypography.titleMedium.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTypography.labelSmall.copyWith(
                                  color: const Color(0xFF76767E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LibraryMaterialCard extends StatelessWidget {
  const _LibraryMaterialCard({
    required this.material,
    required this.assignment,
    required this.onOpen,
    required this.onOpenInteractiveScore,
    required this.onOpenPractice,
  });

  final MusicMaterialDetailDto material;
  final PracticeAssignment? assignment;
  final VoidCallback onOpen;
  final VoidCallback onOpenInteractiveScore;
  final ValueChanged<String> onOpenPractice;

  String? _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final type = material.materialType;
    final skillOrPart = material.targetSkillName?.trim().isNotEmpty == true
        ? material.targetSkillName!.trim()
        : assignment != null && assignment!.vocalPart.trim().isNotEmpty
        ? 'Bè ${assignment!.vocalPart.trim()}'
        : null;
    final sizeLabel = _formatBytes(material.fileSizeBytes);
    final feedback = assignment?.feedbackComment?.trim();
    final primaryActionStyle = FilledButton.styleFrom(
      backgroundColor: MemberChoirStyle.wine,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: MemberChoirStyle.wine,
      side: const BorderSide(color: Color(0xFFD9C7CC)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE6E1D8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  MusicTileIcon(materialType: type, size: 46),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          material.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: const Color(0xFF111C2D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          [type.label, ?skillOrPart, ?sizeLabel].join(' • '),
                          style: AppTypography.bodySmall.copyWith(
                            color: const Color(0xFF45464D),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _LearningBadge(material.learningStatus),
                              if (assignment case final task?) ...[
                                _MetaPill(
                                  icon: Icons.event_outlined,
                                  label:
                                      'Hạn ${DateFormat('dd/MM').format(task.dueDate.toLocal())}',
                                  ink: task.isOverdue
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFF775A00),
                                  fill: task.isOverdue
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFFFFBEB),
                                ),
                                _MetaPill(
                                  icon: Icons.assignment_outlined,
                                  label: task.status.label,
                                  ink: const Color(0xFF1B2541),
                                  fill: const Color(0xFFF0F3FF),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (feedback != null && feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8F5),
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    left: BorderSide(color: Color(0xFFC59B27), width: 3),
                  ),
                ),
                child: Text(
                  'Nhận xét: "$feedback"',
                  style: AppTypography.bodySmall.copyWith(
                    color: const Color(0xFF45464D),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else if (type == MaterialType.lyrics &&
              material.lyricsText?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                material.lyricsText!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: const Color(0xFF76767E),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFCFBF9),
              border: Border(top: BorderSide(color: Color(0xFFF0ECE6))),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (type == MaterialType.interactiveScore) ...[
                  FilledButton.icon(
                    onPressed: onOpenInteractiveScore,
                    style: primaryActionStyle,
                    icon: const Icon(Icons.piano_outlined, size: 17),
                    label: const Text('Mở bản nhạc tương tác'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    style: outlinedStyle,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Xem chi tiết'),
                  ),
                ] else if (type == MaterialType.sampleAudio) ...[
                  FilledButton.icon(
                    onPressed: () => showReferenceAudio(
                      context,
                      songId: material.songId,
                      materialId: material.id,
                      title: material.title,
                    ),
                    style: primaryActionStyle,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Nghe mẫu'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    style: outlinedStyle,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Mở tài liệu'),
                  ),
                ] else if (type == MaterialType.sheetMusic)
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    style: outlinedStyle,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                    label: const Text('Mở bản phổ'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    style: outlinedStyle,
                    icon: Icon(
                      type == MaterialType.lyrics
                          ? Icons.article_outlined
                          : Icons.open_in_new_rounded,
                      size: 17,
                    ),
                    label: Text(
                      type == MaterialType.lyrics
                          ? 'Xem lời hát'
                          : 'Mở tài liệu',
                    ),
                  ),
                if (assignment case final task?)
                  OutlinedButton.icon(
                    onPressed: () => onOpenPractice(task.id),
                    style: outlinedStyle,
                    icon: const Icon(Icons.mic_none_rounded, size: 17),
                    label: Text(
                      task.status == PracticeStatus.pending ||
                              task.status == PracticeStatus.needsRevision
                          ? 'Thu nộp bài'
                          : 'Xem bài tập',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.ink,
    required this.fill,
  });

  final IconData icon;
  final String label;
  final Color ink;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(icon, size: 12, color: ink),
            Text(
              label,
              style: TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningBadge extends StatelessWidget {
  const _LearningBadge(this.status);
  final LearningStatus status;

  @override
  Widget build(BuildContext context) {
    final (ink, fill, border, icon) = switch (status) {
      LearningStatus.learned => (
        const Color(0xFF15803D),
        const Color(0xFFECFDF5),
        const Color(0xFFBBF7D0),
        Icons.check_circle_rounded,
      ),
      LearningStatus.needsPractice => (
        const Color(0xFF775A00),
        const Color(0xFFFFFBEB),
        const Color(0xFFFDE68A),
        Icons.schedule_rounded,
      ),
      LearningStatus.notStarted => (
        const Color(0xFF45464D),
        const Color(0xFFF3F1ED),
        const Color(0xFFE6E1D8),
        Icons.radio_button_unchecked_rounded,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(icon, size: 12, color: ink),
            Text(
              status.label,
              style: TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongFilterOptions {
  final List<LiturgicalSeasonDto> seasons;
  final List<LookupItemDto> massTypes;
  final List<LookupItemDto> ceremonyTypes;
  final List<LookupItemDto> themes;
  final List<LiturgicalSlotDto> slots;
  final List<SkillDto> skills;

  const _SongFilterOptions({
    required this.seasons,
    required this.massTypes,
    required this.ceremonyTypes,
    required this.themes,
    required this.slots,
    required this.skills,
  });
}

class _SongFilterChoice {
  final String id;
  final String label;

  const _SongFilterChoice(this.id, this.label);
}
