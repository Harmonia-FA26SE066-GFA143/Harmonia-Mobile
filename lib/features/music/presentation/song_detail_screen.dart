import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../core/errors/error_messages.dart';
import '../../calendar/data/calendar_repository.dart'
    show publicAppSettingsProvider;
import '../../practice/data/practice_models.dart';
import '../../practice/data/practice_repository.dart';
import '../data/music_dto.dart';
import '../data/song_models.dart' show SongListItem;
import 'music_library_notifier.dart';
import 'music_tile_icon.dart';
import 'reference_audio_panel.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = songDetailProvider(songId);
    final detail = ref.watch(provider);
    final song = detail.asData?.value;
    final choirName =
        ref.watch(publicAppSettingsProvider).asData?.value.choirName.trim() ??
        '';
    final assignment = song == null
        ? null
        : ref
              .watch(practiceListNotifierProvider)
              .asData
              ?.value
              .items
              .where((item) => item.songId == songId)
              .firstOrNull;
    final sheet = song?.materials
        .where((item) => item.materialType == MaterialType.sheetMusic)
        .firstOrNull;
    final score = song?.materials
        .where((item) => item.materialType == MaterialType.interactiveScore)
        .firstOrNull;

    void openPractice() {
      if (assignment == null) return;
      context.push('/practice-detail/${Uri.encodeComponent(assignment.id)}');
    }

    final scaffold = Scaffold(
      backgroundColor: MemberChoirStyle.paper,
      appBar: AppPageHeader(
        gradient: MemberChoirStyle.header,
        titleFontFamily: MemberChoirStyle.displayFont,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (choirName.isNotEmpty)
              Text(
                choirName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: const Color(0xE6FFDF98),
                  fontSize: 10,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const Text(
              'Chi tiết bài hát',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: detail.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: MemberChoirStyle.wine),
          ),
          error: (error, _) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ErrorMessages.forException(error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: MemberChoirStyle.wine,
                    ),
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
          data: (song) {
            if (song == null) {
              return const Center(child: Text('Không tìm thấy bài hát'));
            }
            final audio = song.materials
                .where((item) => item.materialType == MaterialType.sampleAudio)
                .toList();
            final scores = song.materials
                .where(
                  (item) => item.materialType == MaterialType.interactiveScore,
                )
                .toList();
            final sheets = song.materials
                .where((item) => item.materialType == MaterialType.sheetMusic)
                .toList();
            final documents = song.materials
                .where(
                  (item) =>
                      item.materialType != MaterialType.interactiveScore &&
                      item.materialType != MaterialType.sheetMusic &&
                      item.materialType != MaterialType.sampleAudio,
                )
                .toList();
            final hasDirectorNote =
                song.lyrics.trim().isNotEmpty ||
                (song.note?.trim().isNotEmpty == true) ||
                (assignment?.instruction.trim().isNotEmpty == true) ||
                (assignment?.feedbackComment?.trim().isNotEmpty == true);

            return RefreshIndicator(
              color: MemberChoirStyle.wine,
              onRefresh: () async => await ref.refresh(provider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  StitchEntrance(child: _SongOverview(song: song)),
                  if (audio.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    EmbeddedReferenceAudioCard(
                      songId: songId,
                      tracks: audio,
                      onOpenMaterial: (id) =>
                          _openMaterial(context, id, songId),
                    ),
                  ],
                  if (scores.isNotEmpty || sheets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ScoreAndSheetSection(
                      song: song,
                      songId: songId,
                      scores: scores,
                      sheets: sheets,
                      onOpenScore: (id) => _openScore(context, id),
                      onOpenMaterial: (id) =>
                          _openMaterial(context, id, songId),
                    ),
                  ],
                  if (assignment != null ||
                      documents.isNotEmpty ||
                      song.materials.isEmpty) ...[
                    const SizedBox(height: 16),
                    _AssignmentAndDocumentsSection(
                      songId: songId,
                      songHasNoMaterials: song.materials.isEmpty,
                      assignment: assignment,
                      documents: documents,
                      onOpenPractice: openPractice,
                    ),
                  ],
                  if (hasDirectorNote) ...[
                    const SizedBox(height: 16),
                    _DirectorNoteSection(song: song, assignment: assignment),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: assignment == null && sheet == null && score == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                border: const Border(top: BorderSide(color: Color(0x4DC6C6CE))),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  spacing: 12,
                  children: [
                    if (assignment != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: openPractice,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MemberChoirStyle.accent,
                            backgroundColor: MemberChoirStyle.accent.withValues(
                              alpha: 0.05,
                            ),
                            side: const BorderSide(
                              color: MemberChoirStyle.accent,
                            ),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.mic_rounded, size: 18),
                          label: const Text(
                            'Tập hát & Thu âm',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    if (sheet != null || score != null)
                      Expanded(
                        child: FilledButton.icon(
                          style:
                              FilledButton.styleFrom(
                                backgroundColor: MemberChoirStyle.accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ).copyWith(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                            WidgetState.hovered,
                                          ) ||
                                          states.contains(
                                            WidgetState.pressed,
                                          )) {
                                        return MemberChoirStyle.wine;
                                      }
                                      return MemberChoirStyle.accent;
                                    }),
                              ),
                          onPressed: sheet != null
                              ? () => _openMaterial(context, sheet.id, songId)
                              : () => _openScore(context, score!.id),
                          icon: Icon(
                            sheet != null
                                ? Icons.menu_book_rounded
                                : Icons.piano_rounded,
                            size: 18,
                          ),
                          label: Text(
                            sheet != null ? 'Mở bản phổ' : 'Mở trình phát nốt',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
    return Theme(data: MemberChoirStyle.theme(context), child: scaffold);
  }

  static void _openMaterial(BuildContext context, String id, String songId) =>
      context.push(
        Uri(
          pathSegments: ['', 'music-material', id],
          queryParameters: {'songId': songId},
        ).toString(),
      );

  static void _openScore(BuildContext context, String id) =>
      context.push('/interactive-score/${Uri.encodeComponent(id)}');
}

class _SongOverview extends StatelessWidget {
  const _SongOverview({required this.song});

  final SongListItem song;

  @override
  Widget build(BuildContext context) {
    final classification = song.classification;
    final topBadges = [
      ...?classification?.liturgicalSeasons.map((season) => season.name),
      ...?classification?.liturgicalSlots.map((slot) => slot.name),
    ].where((tag) => tag.trim().isNotEmpty).toSet();
    final subTags = [
      ...?classification?.songThemes.map((t) => t.name),
      ...?classification?.massTypes.map((m) => m.name),
      ...?classification?.ceremonyTypes.map((c) => c.name),
      ...?classification?.vocalRequirements.map((v) => v.skillName),
    ].where((tag) => tag.trim().isNotEmpty).toSet();

    final facts = [
      if (song.composer.trim().isNotEmpty)
        (Icons.edit_note_rounded, 'Tác giả', song.composer.trim()),
      if (song.tone.trim().isNotEmpty)
        (Icons.music_note_rounded, 'Điệu thức (Key)', song.tone.trim()),
      if (song.tempo.trim().isNotEmpty)
        (Icons.speed_rounded, 'Nhịp & Sắc thái', song.tempo.trim()),
      if (song.materials.isNotEmpty)
        (
          Icons.library_music_outlined,
          'Tài liệu của bạn',
          '${song.materials.length} tài liệu',
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4DC6C6CE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1B2541),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                const Positioned.fill(
                  child: MemberChoirArt(
                    artwork: MemberChoirArtwork.song,
                    height: 176,
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xE66D2636),
                        Color(0x666D2636),
                        Color(0x33000000),
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 176),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (topBadges.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MemberChoirStyle.paper.withValues(
                                alpha: 0.94,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 6,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    topBadges.join(' • ').toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1B2541),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 8),
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subTags.isNotEmpty) ...[
                              Text(
                                subTags.join(' · ').toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFDF98),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              song.title,
                              style: AppTypography.headlineSmall.copyWith(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                fontFamily: MemberChoirStyle.displayFont,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (facts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final half =
                        constraints.maxWidth >= 270 &&
                        MediaQuery.textScalerOf(context).scale(14) < 23;
                    final width = half
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (icon, label, value) in facts)
                          Container(
                            width: width,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: MemberChoirStyle.paper,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x99E6E1D8),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              spacing: 8,
                              children: [
                                Icon(
                                  icon,
                                  color: MemberChoirStyle.accent,
                                  size: 18,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        label.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: const Color(0xFF76767E),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        value,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: const Color(0xFF111C2D),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreAndSheetSection extends StatelessWidget {
  const _ScoreAndSheetSection({
    required this.song,
    required this.songId,
    required this.scores,
    required this.sheets,
    required this.onOpenScore,
    required this.onOpenMaterial,
  });

  final SongListItem song;
  final String songId;
  final List<MusicMaterialDto> scores;
  final List<MusicMaterialDto> sheets;
  final ValueChanged<String> onOpenScore;
  final ValueChanged<String> onOpenMaterial;

  String? _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final total = scores.length + sheets.length;
    return _SongCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: MemberChoirStyle.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scores.isNotEmpty ? 'Bản Phổ Tương Tác' : 'Bản Phổ Nhạc',
                  style: AppTypography.titleMedium.copyWith(
                    color: const Color(0xFF111C2D),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$total tài liệu',
                style: const TextStyle(
                  color: MemberChoirStyle.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          for (final item in scores)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6E1D8)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onOpenScore(item.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 10,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                [
                                  'BẢN NHẠC TƯƠNG TÁC',
                                  if (item.targetSkillName?.trim().isNotEmpty ==
                                      true)
                                    item.targetSkillName!.trim().toUpperCase(),
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF76767E),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            if (song.tone.trim().isNotEmpty)
                              Text(
                                song.tone.trim(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: MemberChoirStyle.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 1, color: Color(0xFFE6E1D8)),
                        Row(
                          children: [
                            const MusicTileIcon(
                              materialType: MaterialType.interactiveScore,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: const Color(0xFF111C2D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Text(
                                    'Xem cao độ & đồng bộ nốt theo audio',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF45464D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => onOpenMaterial(item.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF111C2D),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFFE6E1D8),
                                ),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(
                                Icons.description_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'Tài liệu',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => onOpenScore(item.id),
                              style: FilledButton.styleFrom(
                                backgroundColor: MemberChoirStyle.accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.piano_rounded, size: 16),
                              label: const Text(
                                'Mở trình phát nốt',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          for (final item in sheets)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6E1D8)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onOpenMaterial(item.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 10,
                      children: [
                        Row(
                          children: [
                            const MusicTileIcon(
                              materialType: MaterialType.sheetMusic,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: const Color(0xFF111C2D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    [
                                      'Bản phổ PDF',
                                      if (item.targetSkillName
                                              ?.trim()
                                              .isNotEmpty ==
                                          true)
                                        item.targetSkillName!.trim(),
                                      ?_formatSize(item.fileSizeBytes),
                                    ].join(' • '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF45464D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton.icon(
                            onPressed: () => onOpenMaterial(item.id),
                            style: FilledButton.styleFrom(
                              backgroundColor: MemberChoirStyle.accent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Mở bản phổ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _AssignmentAndDocumentsSection extends StatelessWidget {
  const _AssignmentAndDocumentsSection({
    required this.songId,
    required this.songHasNoMaterials,
    required this.assignment,
    required this.documents,
    required this.onOpenPractice,
  });

  final String songId;
  final bool songHasNoMaterials;
  final PracticeAssignment? assignment;
  final List<MusicMaterialDto> documents;
  final VoidCallback onOpenPractice;

  @override
  Widget build(BuildContext context) {
    final badgeBg = assignment?.status == PracticeStatus.passed
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFFBEB);
    final badgeFg = assignment?.status == PracticeStatus.passed
        ? const Color(0xFF065F46)
        : const Color(0xFF92400E);
    final badgeBorder = assignment?.status == PracticeStatus.passed
        ? const Color(0xFFA7F3D0)
        : const Color(0xFFFDE68A);

    return _SongCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  const Icon(
                    Icons.assignment_ind_rounded,
                    size: 22,
                    color: MemberChoirStyle.accent,
                  ),
                  Flexible(
                    child: Text(
                      'Phân Công & Tài Liệu',
                      style: AppTypography.titleMedium.copyWith(
                        color: const Color(0xFF111C2D),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (assignment != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Text(
                    assignment!.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeFg,
                    ),
                  ),
                ),
            ],
          ),
          if (assignment != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MemberChoirStyle.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6E1D8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 10,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B2541),
                      shape: BoxShape.circle,
                    ),
                    child: assignment!.vocalPart.trim().isNotEmpty
                        ? Text(
                            assignment!.vocalPart.trim()[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFFECE57),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          )
                        : const Icon(
                            Icons.mic_none_rounded,
                            color: Color(0xFFFECE57),
                            size: 18,
                          ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment!.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111C2D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (assignment!.vocalPart.trim().isNotEmpty)
                              'Bè: ${assignment!.vocalPart.trim()}',
                            'Hạn: ${DateFormat('dd/MM/yyyy').format(assignment!.dueDate.toLocal())}',
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF76767E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenPractice,
                    style: TextButton.styleFrom(
                      foregroundColor: MemberChoirStyle.accent,
                      backgroundColor: MemberChoirStyle.accent.withValues(
                        alpha: 0.10,
                      ),
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      assignment!.status == PracticeStatus.passed
                          ? 'Xem bài tập'
                          : 'Ghi âm nộp',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (songHasNoMaterials)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x99E6E1D8)),
              ),
              child: const Text(
                'Chưa có tài liệu phù hợp với kỹ năng của bạn cho bài hát này.',
                style: TextStyle(fontSize: 13, color: Color(0xFF45464D)),
              ),
            ),
          for (final material in documents)
            _SongMaterialCard(material: material, songId: songId),
        ],
      ),
    );
  }
}

class _DirectorNoteSection extends StatelessWidget {
  const _DirectorNoteSection({required this.song, this.assignment});

  final SongListItem song;
  final PracticeAssignment? assignment;

  @override
  Widget build(BuildContext context) {
    final mainNote = song.lyrics.trim();
    final itemNote = song.note?.trim() ?? '';
    final instruction = assignment?.instruction.trim() ?? '';
    final feedback = assignment?.feedbackComment?.trim() ?? '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4DC6C6CE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2541),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: MemberChoirStyle.accent, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    const Icon(
                      Icons.forum_outlined,
                      size: 20,
                      color: MemberChoirStyle.accent,
                    ),
                    Expanded(
                      child: Text(
                        'Ghi chú & Dặn dò',
                        style: AppTypography.titleMedium.copyWith(
                          color: const Color(0xFF111C2D),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (mainNote.isNotEmpty) _noteQuote(mainNote),
                if (itemNote.isNotEmpty && itemNote != mainNote)
                  _noteQuote(itemNote),
                if (instruction.isNotEmpty &&
                    instruction != mainNote &&
                    instruction != itemNote)
                  _noteQuote('Hướng dẫn tập: $instruction'),
                if (feedback.isNotEmpty)
                  _noteQuote(
                    assignment?.feedbackDate != null
                        ? 'Nhận xét (${DateFormat('dd/MM/yyyy').format(assignment!.feedbackDate!.toLocal())}): $feedback'
                        : 'Nhận xét: $feedback',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _noteQuote(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFAF8F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x99E6E1D8)),
    ),
    child: Text(
      text,
      style: AppTypography.bodyMedium.copyWith(
        color: const Color(0xFF45464D),
        fontSize: 13,
        fontStyle: FontStyle.italic,
        height: 1.45,
      ),
    ),
  );
}

class _SongCardShell extends StatelessWidget {
  const _SongCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x4DC6C6CE)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A1B2541),
          blurRadius: 20,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _SongMaterialCard extends StatelessWidget {
  const _SongMaterialCard({required this.material, required this.songId});
  final MusicMaterialDto material;
  final String songId;

  @override
  Widget build(BuildContext context) {
    final type = material.materialType;
    final progress = material is MusicMaterialDetailDto
        ? (material as MusicMaterialDetailDto).learningStatus
        : null;
    void open() => context.push(
      Uri(
        pathSegments: ['', 'music-material', material.id],
        queryParameters: {'songId': songId},
      ).toString(),
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E1D8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    MusicTileIcon(materialType: type, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.title,
                            style: AppTypography.labelLarge.copyWith(
                              color: const Color(0xFF111C2D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              type.label,
                              ?material.targetSkillName,
                              ?progress?.label,
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF76767E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: MemberChoirStyle.accent,
                    ),
                  ],
                ),
                if (material.lyricsText?.trim().isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x99E6E1D8)),
                    ),
                    child: Text(
                      material.lyricsText!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF45464D),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: MemberChoirStyle.wine,
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(
                      type == MaterialType.lyrics
                          ? 'Xem toàn bộ lời hát'
                          : 'Mở tài liệu',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: open,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
