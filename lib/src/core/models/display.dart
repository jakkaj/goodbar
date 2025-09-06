import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:goodbar/src/core/models/geometry.dart';

part 'display.freezed.dart';
part 'display.g.dart';

@freezed
sealed class Display with _$Display {
  const Display._();
  
  @JsonSerializable(explicitToJson: true)
  const factory Display({
    required String id,
    required Rectangle bounds,
    required Rectangle workArea,
    required double scaleFactor,
    required bool isPrimary,
  }) = _Display;

  double get width => bounds.width;
  double get height => bounds.height;
  
  double get workWidth => workArea.width;
  double get workHeight => workArea.height;
  
  double get menuBarHeight => workArea.y - bounds.y;
  double get dockHeight => (bounds.y + bounds.height) - (workArea.y + workArea.height);

  factory Display.fromJson(Map<String, dynamic> json) => 
      _$DisplayFromJson(json);
}

@freezed
sealed class DisplayChangeEvent with _$DisplayChangeEvent {
  @JsonSerializable(explicitToJson: true)
  const factory DisplayChangeEvent({
    required List<Display> displays,
    required String changeType,
    required DateTime timestamp,
  }) = _DisplayChangeEvent;

  factory DisplayChangeEvent.fromJson(Map<String, dynamic> json) => 
      _$DisplayChangeEventFromJson(json);
}
