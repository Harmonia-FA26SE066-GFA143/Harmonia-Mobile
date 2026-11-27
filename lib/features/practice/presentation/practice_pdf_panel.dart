import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/harmonia_svg_art.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../../music/data/music_dto.dart';
import '../../music/data/music_file_loader.dart';
import '../../music/data/music_repository.dart';
import '../../music/presentation/material_pdf_reader.dart';

bool _isPdf(MusicMaterialDetailDto material) =>
    material.fileName.toLowerCase().endsWith('.pdf');

final _practicePdfListProvider = FutureProvider.autoDispose
    .family<List<MusicMaterialDetailDto>, String>((ref, songId) async {
      ref.watch(
        sessionManagerProvider.select((session) => session.sessionEpoch),
      );
      final repository = ref.watch(musicRepositoryProvider);
      final pdfs = <String, MusicMaterialDetailDto>{};
      var page = 1;
      while (ref.mounted) {
        final result = await repository.getMyMaterialsPage(
          SearchMusicMaterialsRequest(songId: songId, pageNumber: page),
        );
        for (final material in result.items) {
          if (material.songId == songId && _isPdf(material)) {
            pdfs[material.id] = material;
          }
        }
        if (!result.hasNextPage || result.pageNumber < page) break;
        page = result.pageNumber + 1;
      }
      return pdfs.values.toList();
    });

final _practicePdfFileProvider = FutureProvider.autoDispose
    .family<CachedMusicPdf, ({String songId, String materialId})>((
      ref,
      identity,
    ) async {
      ref.watch(
        sessionManagerProvider.select((session) => session.sessionEpoch),
      );
      final repository = ref.watch(musicRepositoryProvider);
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final material = await repository.getMyMaterial(
        identity.materialId,
        identity.songId,
      );
      if (!ref.mounted) throw StateError('PDF request cancelled.');
      if (material == null || !_isPdf(material)) {
        throw const AppException(
          code: 'MATERIAL_PDF_UNAVAILABLE',
          message: 'Tài liệu PDF không còn khả dụng.',
        );
      }
      final pdf = await MusicFileLoader().downloadPdf(material.fileUrl, token);
      if (!ref.mounted) {
        await pdf.dispose();
        throw StateError('PDF request cancelled.');
      }
      ref.onDispose(() => unawaited(pdf.dispose()));
      return pdf;
    }, retry: (_, _) => null);

class PracticePdfPanel extends ConsumerStatefulWidget {
  const PracticePdfPanel({
    super.key,
    required this.songId,
    required this.attachedMaterialIds,
  });

  final String songId;
  final List<String> attachedMaterialIds;

  @override
  ConsumerState<PracticePdfPanel> createState() => _PracticePdfPanelState();
}

class _PracticePdfPanelState extends ConsumerState<PracticePdfPanel> {
  String? _selectedId;

  Widget _error(Object error, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ErrorMessages.forException(
              error,
              defaultMessage: 'Không thể mở PDF. Vui lòng thử lại.',
            ),
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final listProvider = _practicePdfListProvider(widget.songId);
    return ref
        .watch(listProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox.shrink(),
          error: (error, _) => const SizedBox.shrink(),
          data: (materials) {
            if (materials.isEmpty) return const SizedBox.shrink();
            final byId = {
              for (final material in materials) material.id: material,
            };
            final selected =
                byId[_selectedId] ??
                widget.attachedMaterialIds
                    .map((id) => byId[id])
                    .nonNulls
                    .firstOrNull ??
                materials.first;
            final fileProvider = _practicePdfFileProvider((
              songId: widget.songId,
              materialId: selected.id,
            ));
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: materials.length == 1
                          ? Text(
                              selected.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            )
                          : MemberChoiceField<String>(
                              label: 'Tài liệu PDF',
                              value: selected.id,
                              items: [
                                for (final material in materials)
                                  DropdownMenuItem(
                                    value: material.id,
                                    child: Text(
                                      material.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (id) =>
                                  setState(() => _selectedId = id),
                            ),
                    ),
                    SizedBox(
                      height: (MediaQuery.sizeOf(context).height * 0.48).clamp(
                        240.0,
                        520.0,
                      ),
                      child: ref
                          .watch(fileProvider)
                          .when(
                            skipLoadingOnRefresh: false,
                            loading: () =>
                                const Center(child: HarmoniaNeumeSpinner()),
                            error: (error, _) => _error(
                              error,
                              () => ref.invalidate(fileProvider),
                            ),
                            data: (pdf) => MaterialPdfReader(
                              key: ObjectKey(pdf),
                              filePath: pdf.file.path,
                              initialPage: 0,
                              busy: false,
                              onPageChanged: (_) {},
                              onReload: () => ref.invalidate(fileProvider),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}
