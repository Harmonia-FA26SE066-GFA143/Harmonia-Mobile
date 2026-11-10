import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../core/errors/error_messages.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../calendar/data/calendar_repository.dart';
import '../data/music_dto.dart';
import '../../lookups/data/lookup_dto.dart';
import '../../lookups/data/lookups_api_service.dart';
import 'music_library_notifier.dart';
import 'music_tile_icon.dart';

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
  bool _showSongFilters = false;
  Future<_SongFilterOptions>? _filterOptionsFuture;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(musicLibraryProvider).keyword;
  }

  @override
  void dispose() {
    _search.dispose();
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

  Widget _searchBar(MusicLibraryNotifier notifier, {required bool onRed}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(
        color: onRed ? Colors.transparent : AppColors.border,
      ),
    );
    void search() {
      FocusScope.of(context).unfocus();
      notifier.refresh(keyword: _search.text);
    }

    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => search(),
      decoration: InputDecoration(
        fillColor: onRed ? const Color(0xFFFFF4F6) : Colors.white,
        hintText: 'Tìm bài hát, tác giả hoặc tài liệu…',
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        prefixIcon: Icon(
          Icons.search,
          color: onRed ? AppColors.primary : AppColors.muted,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(4),
          child: IconButton(
            tooltip: 'Tìm kiếm',
            style: onRed
                ? IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  )
                : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: search,
          ),
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
      ),
    );
  }

  Widget _tabs(MusicLibraryState state, MusicLibraryNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: state.materialsTab ? const Color(0x2BFFFFFF) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: state.materialsTab ? Colors.transparent : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          for (final materials in [false, true])
            Expanded(
              child: Semantics(
                selected: state.materialsTab == materials,
                child: TextButton(
                  onPressed: () {
                    if (state.materialsTab == materials) return;
                    setState(() => _showSongFilters = false);
                    notifier.refresh(
                      materialsTab: materials,
                      keyword: _search.text,
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 8,
                    ),
                    shape: const StadiumBorder(),
                    backgroundColor: state.materialsTab != materials
                        ? Colors.transparent
                        : materials
                        ? Colors.white
                        : AppColors.primary,
                    foregroundColor: state.materialsTab == materials
                        ? materials
                              ? AppColors.primary
                              : Colors.white
                        : state.materialsTab
                        ? const Color(0xFFFFE9ED)
                        : AppColors.body,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.materialsTab == materials
                            ? Icons.check_circle_outline
                            : materials
                            ? Icons.menu_book_outlined
                            : Icons.library_music_outlined,
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          materials ? 'Tài liệu của tôi' : 'Bài hát',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            'MÙA',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 9),
          ChoiceChip(
            label: const Text('Tất cả'),
            selected: state.liturgicalSeasonId == null,
            onSelected: (_) => select(null),
          ),
          for (final season in seasons) ...[
            const SizedBox(width: 7),
            ChoiceChip(
              label: Text(season.name),
              selected: state.liturgicalSeasonId == season.id,
              onSelected: (selected) => select(selected ? season.id : null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _materialFilters(
    MusicLibraryState state,
    MusicLibraryNotifier notifier,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<MaterialType>(
            key: ValueKey(('type', state.materialType)),
            initialValue: state.materialType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Loại tài liệu'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tất cả')),
              for (final type in MaterialType.filterOptions)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) => notifier.refresh(
              materialType: value,
              learningStatus: state.learningStatus,
              replaceFilters: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<LearningStatus>(
            key: ValueKey(('status', state.learningStatus)),
            initialValue: state.learningStatus,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tiến độ'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tất cả')),
              for (final status in LearningStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) => notifier.refresh(
              materialType: state.materialType,
              learningStatus: value,
              replaceFilters: true,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);
    final title = state.materialsTab ? 'Plus Jakarta Sans' : 'Be Vietnam Pro';
    final search = _searchBar(notifier, onRed: !state.materialsTab);
    final tabs = _tabs(state, notifier);
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

    return Scaffold(
      backgroundColor: state.materialsTab
          ? const Color(0xFFF7F7FC)
          : AppColors.background,
      appBar: AppPageHeader(
        roundedBottom: true,
        centerTitle: true,
        titleFontFamily: state.materialsTab ? 'Playfair Display' : null,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thư viện thánh ca'),
            if (!state.materialsTab)
              Text(
                'Harmonia Sacred Music Liturgy',
                style: AppTypography.bodySmall.copyWith(
                  color: const Color(0xFFFFDCE5),
                ),
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
          if (!state.materialsTab)
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
        ],
        gradient: state.materialsTab
            ? const LinearGradient(
                colors: [Color(0xFFE11B1B), Color(0xFFC51313)],
              )
            : AppColors.brandGradient,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: state.materialsTab ? tabs : search,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => notifier.refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              if (!state.materialsTab) ...[
                tabs,
                _seasonChips(state, notifier),
                if (_showSongFilters) _buildSongFilters(state, notifier),
              ] else ...[
                search,
                _materialFilters(state, notifier),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đang hiển thị ${state.materials.length} mục học tập',
                        style: TextStyle(
                          fontFamily: title,
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _search.clear();
                        notifier.refresh(keyword: '', replaceFilters: true);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Đặt lại'),
                    ),
                  ],
                ),
              ],
              if (state.loading) const LinearProgressIndicator(),
              if (state.error case final error?)
                Card(
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
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!state.loading && state.error == null && state.isEmpty)
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
              if (!state.materialsTab)
                for (final song in state.songs)
                  StitchEntrance(
                    key: ValueKey(song.id),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const MusicTileIcon(
                          materialType: MaterialType.sampleAudio,
                        ),
                        title: Text(
                          song.title,
                          style: AppTypography.titleMedium,
                        ),
                        subtitle: Text(
                          [
                            if (song.composer?.trim().isNotEmpty == true)
                              song.composer!,
                            if (song.musicalKey?.trim().isNotEmpty == true)
                              'Cung ${song.musicalKey}',
                          ].join(' • '),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.outline,
                        ),
                        onTap: () => context.push(
                          '/song-detail/${Uri.encodeComponent(song.id)}',
                        ),
                      ),
                    ),
                  ),
              if (state.materialsTab)
                for (final material in state.materials)
                  StitchEntrance(
                    key: ValueKey(material.id),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: MusicTileIcon(
                          materialType: material.materialType,
                        ),
                        title: Text(
                          material.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            fontFamily: title,
                          ),
                        ),
                        subtitle: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 7,
                          runSpacing: 4,
                          children: [
                            Text(
                              material.materialType.label,
                              style: TextStyle(fontFamily: title),
                            ),
                            _LearningBadge(material.learningStatus),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.outline,
                        ),
                        onTap: () async {
                          await context.push(
                            Uri(
                              pathSegments: ['', 'music-material', material.id],
                              queryParameters: {'songId': material.songId},
                            ).toString(),
                          );
                          if (mounted) {
                            await ref
                                .read(musicLibraryProvider.notifier)
                                .refresh();
                          }
                        },
                      ),
                    ),
                  ),
              if (state.hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: OutlinedButton(
                    onPressed: state.loading || state.loadingMore
                        ? null
                        : notifier.loadMore,
                    child: state.loadingMore
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tải thêm'),
                  ),
                ),
              if (nextEvent != null)
                Card(
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
            ],
          ),
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
    final (ink, fill, icon) = switch (status) {
      LearningStatus.learned => (
        AppColors.statusSuccess,
        AppColors.statusSuccessSoft,
        Icons.check_rounded,
      ),
      LearningStatus.needsPractice => (
        AppColors.statusWarning,
        AppColors.statusWarningSoft,
        Icons.circle,
      ),
      LearningStatus.notStarted => (
        AppColors.body,
        AppColors.surfaceContainerHigh,
        Icons.circle_outlined,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink.withValues(alpha: .2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: ink),
            const SizedBox(width: 4),
            Text(
              status.label,
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
