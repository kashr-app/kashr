import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/cubit/transfer_editor_state.freezed.dart';

@freezed
abstract class TransferEditorState with _$TransferEditorState {
  const factory TransferEditorState.initial() = _Initial;
  const factory TransferEditorState.loading() = _Loading;
  const factory TransferEditorState.loaded({
    required TransferWithDetails details,
  }) = _Loaded;
  const factory TransferEditorState.error(String message) = _Error;
}
