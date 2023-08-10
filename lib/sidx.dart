import 'dart:math';

class Sidx {
  int index = 0;
  List<int> buffer;
  Sidx(this.buffer);

  // startRange 最小值是indexEndoffset+1 , endRange 最大值是文件大小(自动读出来的),下一块的start值等于上一块的end值
  parse(int indexEndoffset) {
    read(8, ignore: true); //  跳过8字节header
    final int versionAndFlags = read(4);
    final version = versionAndFlags >> 24; // version 只是高8位
    final flags = versionAndFlags & 0xFFFFFF;
    final referenceId = read(4);
    final timeScale = read(4);
    var earliest_presentation_time = 0;
    var first_offset = 0;
    if (version == 0) {
      earliest_presentation_time = read(4);
      first_offset = read(4);
    } else {
      earliest_presentation_time = read(8);
      first_offset = read(8);
    }
    first_offset += indexEndoffset + 1;
    read(2, ignore: true); // skip reserved
    final reference_count = read(2);
    var references = [];
    var time = earliest_presentation_time;
    var offset = first_offset;
    for (var i = 0; i < reference_count; i++) {
      const reference_type = 0;
      final reference_size = read(4);
      final subsegment_duration = read(4);
      // 下面是 starts_with_SAP, SAP_type, SAP_delta_time 没用到,这里忽略掉
      read(4, ignore: true);
      final startRange = offset;
      final endRange = offset + reference_size;
      references.add({
        "reference_type": reference_type,
        "reference_size": reference_size,
        "subsegment_duration": subsegment_duration,
        "durationSec": subsegment_duration / timeScale,
        "startTimeSec": time / timeScale,
        "startRange": startRange,
        "endRange": endRange,
      });
      offset += reference_size;
      time += subsegment_duration;
    }
    return {
      "version": version,
      "flag": flags,
      "referenceId": referenceId,
      "timeScale": timeScale,
      "earliest_presentation_time": earliest_presentation_time,
      "first_offset": first_offset,
      "reference_count": reference_count,
      "references": references,
    };
  }

  int read(int n, {ignore = false}) {
    if (ignore) {
      index += n;
      return 0;
    }
    final start = index;
    int value = 0;
    for (var i = 0; i < n; i++) {
      value *= pow(2, 8).toInt();
      value += buffer[start + i];
    }
    index += n;
    return value;
  }

  static List<List<int>> toInfo(info) {
    final List<List<int>> res = [];
    for (final item in info['references']) {
      res.add([item["startRange"], item["endRange"]]);
    }
    return res;
  }
}
