import 'package:freezed_annotation/freezed_annotation.dart';

part 'geometry.freezed.dart';
part 'geometry.g.dart';

@freezed
sealed class Point with _$Point {
  const factory Point({
    required double x,
    required double y,
  }) = _Point;

  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);
}

@freezed
sealed class Rectangle with _$Rectangle {
  const Rectangle._();
  
  const factory Rectangle({
    required double x,
    required double y,
    required double width,
    required double height,
  }) = _Rectangle;

  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;
  
  Point get origin => Point(x: x, y: y);
  Point get center => Point(x: x + width / 2, y: y + height / 2);
  
  bool contains(Point point) {
    return point.x >= left && 
           point.x <= right && 
           point.y >= top && 
           point.y <= bottom;
  }

  factory Rectangle.fromJson(Map<String, dynamic> json) => 
      _$RectangleFromJson(json);
}