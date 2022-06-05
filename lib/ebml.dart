import 'dart:math';

class EbmlUtils {
  // 传入一个字节8位, 判断前多少个bit是0, 返回值可能为 0 - 8
  static int vIntWidth(int s) {
    if (s < 1) {
      return 8;
    }
    var width = 0;
    for (width = 0; width < 8; width++) {
      if (s >= pow(2, (7 - width))) {
        break;
      }
    }
    return width;
  }

  // 传入若干个字节 最高位1置为0后转为十进制数
  static int vIntNum(int byte) {
    var x = byte;
    var k = 0;
    if ((x >> (k ^ 32)) > 0) k = k ^ 32;
    if ((x >> (k ^ 16)) > 0) k = k ^ 16;
    if ((x >> (k ^ 8)) > 0) k = k ^ 8;
    if ((x >> (k ^ 4)) > 0) k = k ^ 4;
    if ((x >> (k ^ 2)) > 0) k = k ^ 2;
    if ((x >> (k ^ 1)) > 0) k = k ^ 1;
    x = x ^ (1 << k);
    return x;
  }
}

class EBMLParserTypes {
  static final types = {
    '1c53bb6b': ['Cues', 'm'], // lvl. 1
    'bb': ['CuePoint', 'm'], // lvl. 2
    'b3': ['CueTime', 'u'], // lvl. 3
    'b7': ['CueTrackPositions', 'm'], // lvl. 3
    'f7': ['CueTrack', 'u'], // lvl. 4
    'f1': ['CueClusterPosition', 'u'], // lvl. 4
  };

  static info(String id) {
    if (types[id] != null) {
      return types[id];
    }
    return ['', ''];
  }
}

class EBMLParserBuffer {
  List<int> buffer;
  int index = 0;
  EBMLParserBuffer(this.buffer);
  parse() {
    if (index < buffer.length) {
      return readVint();
    }
  }

  readVint() {
    var s = read(1);
    var w = EbmlUtils.vIntWidth(s) + 1;
    rewind(1);
    int id = read(w);
    final meta = EBMLParserTypes.info(id.toRadixString(16));
    s = read(1);
    w = EbmlUtils.vIntWidth(s) + 1;
    rewind(1);
    final len = read(w);
    final lenNum = EbmlUtils.vIntNum(len);
    final data = read(lenNum, number: meta[1] == 'u');
    return {
      "id": id.toRadixString(16),
      "meta": meta,
      "data": data,
    };
  }

  read(int n, {bool number = true}) {
    final last = buffer.length - index;
    if (n > last) {
      n = last;
    }
    if (!number) {
      final r = buffer.sublist(index, index + n);
      index += n;
      return r;
    }

    num value = 0;
    int start = index;
    for (var i = 0; i < n; i++) {
      value *= pow(2, 8);
      value += buffer[start + i];
    }
    index += n;
    return value;
  }

  rewind(int n) {
    index -= n;
  }
}

class EBMLParserElement {
  String id = "";
  String name = "";
  String type = "";
  dynamic value;
  EBMLParserBuffer buffer;
  List<EBMLParserElement> children = [];
  EBMLParserElement(List<int> buf) : buffer = EBMLParserBuffer(buf);

  List<EBMLParserElement> parseElements() {
    while (true) {
      final item = buffer.parse();
      if (item == null) {
        break;
      }
      final ele = parseElement(item['id'], item['meta'], item['data']);
      children.add(ele);
    }
    return children;
  }

  EBMLParserElement parseElement(String id, List<String> meta, dynamic data) {
    final element = EBMLParserElement(data is int ? [data] : data);
    element.id = id;
    element.name = meta[0];
    element.type = meta[1];
    if (element.type == 'm') {
      element.parseElements();
    } else {
      element.value = element.type == 'u' ? data : data;
    }
    return element;
  }
}

class EbmlParser {
  List<int> buffer;
  EbmlParser(this.buffer);
  List<EBMLParserElement> parse() {
    final parser = EBMLParserElement(buffer);
    final data = parser.parseElements();
    return data;
  }

  // start 最小值是indexEndOffset+1, end 最大值等于文件大小.
  static List<List<int>> toInfo(
      List<EBMLParserElement> data, int indexEndOffset, int totalSize) {
    final List<List<int>> info = [];
    data[0].children.forEach((element) {
      if (element.id == "bb") {
        final cueTime = element.children[0];
        final cueTrackPositions = element.children[1];
        // final CueTrack = CueTrackPositions.children[0];
        final cueClusterPosition = cueTrackPositions.children[1];
        info.add([cueTime.value, cueClusterPosition.value]);
      }
    });
    var segmentStart = indexEndOffset - info[0][1] + 1;
    var segmentEnd = totalSize;
    final l = info.length - 1;
    List<List<int>> res = [];
    for (var i = 0; i < info.length; i++) {
      var item = info[i];
      var start = item[1] + segmentStart;
      var end = 0;
      if (i < l) {
        end = info[i + 1][1] + segmentStart;
      } else {
        // last item,range end is its length
        end = segmentEnd;
      }
      res.add([start, end]);
    }
    return res;
  }
}
