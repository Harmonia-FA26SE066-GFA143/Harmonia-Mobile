import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/error_messages.dart';
import '../data/music_dto.dart';
import '../../lookups/data/lookup_dto.dart';
import '../../lookups/data/lookups_api_service.dart';
import 'music_library_notifier.dart';

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
            for (final item in MaterialType.values)
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
                          missingMaterialType: MaterialType.values
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thư viện thánh ca')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Tìm bài hát hoặc tài liệu',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Tìm kiếm',
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () =>
                              notifier.refresh(keyword: _search.text),
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) => notifier.refresh(keyword: value),
                    ),
                  ),
                  if (!state.materialsTab) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _toggleSongFilters,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: Icon(
                        _showSongFilters
                            ? Icons.filter_alt_off_outlined
                            : Icons.filter_alt_outlined,
                      ),
                      label: const Text('Bộ lọc'),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Bài hát'),
                      icon: Icon(Icons.library_music),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Tài liệu của tôi'),
                      icon: Icon(Icons.menu_book),
                    ),
                  ],
                  selected: {state.materialsTab},
                  onSelectionChanged: (value) {
                    setState(() => _showSongFilters = false);
                    notifier.refresh(
                      materialsTab: value.single,
                      keyword: _search.text,
                    );
                  },
                ),
              ),
            ),
            if (_showSongFilters && !state.materialsTab)
              _buildSongFilters(state, notifier),
            if (state.materialsTab)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<MaterialType>(
                        key: ValueKey(('type', state.materialType)),
                        initialValue: state.materialType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Loại tài liệu',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          for (final type in MaterialType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
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
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          for (final status in LearningStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
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
              ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => notifier.refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.error != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(state.error!, textAlign: TextAlign.center),
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
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Text(
                          state.keyword.isNotEmpty ||
                                  state.hasSongFilters ||
                                  state.materialType != null ||
                                  state.learningStatus != null
                              ? 'Không có kết quả phù hợp'
                              : state.materialsTab
                              ? 'Bạn chưa có tài liệu học'
                              : 'Thư viện chưa có bài hát',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!state.materialsTab)
                      for (final song in state.songs)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.music_note,
                              color: AppColors.primary,
                            ),
                            title: Text(song.title),
                            subtitle: song.composer?.isNotEmpty == true
                                ? Text(song.composer!)
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '/song-detail/${Uri.encodeComponent(song.id)}',
                            ),
                          ),
                        ),
                    if (state.materialsTab)
                      for (final material in state.materials)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              material.materialType == MaterialType.sampleAudio
                                  ? Icons.audiotrack
                                  : Icons.description,
                              color: AppColors.primary,
                            ),
                            title: Text(material.title),
                            subtitle: Text(
                              '${material.materialType.label} • ${material.learningStatus.label}'
                              '${material.targetSkillName == null ? "" : "\n${material.targetSkillName}"}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await context.push(
                                Uri(
                                  path: '/music-material/${material.id}',
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
                    if (state.hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: OutlinedButton(
                          onPressed: state.loading || state.loadingMore
                              ? null
                              : notifier.loadMore,
                          child: state.loadingMore
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Tải thêm'),
                        ),
                      ),
                  ],
                ),
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
