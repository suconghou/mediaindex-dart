import 'ebml.dart';
import 'sidx.dart';

class mediaindex {
  final List<int> data;
  final int indexEndOffset;
  final int totalSize;
  mediaindex(this.data, this.indexEndOffset, this.totalSize);

  List<List<int>> parse(bool webm) {
    if (webm) {
      return parseWebm();
    }
    return parseMp4();
  }

  List<List<int>> parseWebm() {
    final info = EbmlParser(data).parse();
    return EbmlParser.toInfo(info, indexEndOffset, totalSize);
  }

  List<List<int>> parseMp4() {
    final info = Sidx(data).parse(indexEndOffset);
    return Sidx.toInfo(info);
  }
}
