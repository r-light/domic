// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dto.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PageDataAdapter extends TypeAdapter<PageData> {
  @override
  final int typeId = 2;

  @override
  PageData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PageData(
      fields[0] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PageData obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.pageCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ComicSimpleAdapter extends TypeAdapter<ComicSimple> {
  @override
  final int typeId = 3;

  @override
  ComicSimple read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComicSimple(
      fields[0] as String,
      fields[1] as String,
      fields[2] as String,
      fields[3] as String,
      fields[4] as String,
      fields[5] as String,
      fields[6] as String,
    )
      ..categories = (fields[7] as List?)?.cast<String>()
      ..tags = (fields[8] as List?)?.cast<String>()
      ..star = fields[9] as String?;
  }

  @override
  void write(BinaryWriter writer, ComicSimple obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.thumb)
      ..writeByte(3)
      ..write(obj.author)
      ..writeByte(4)
      ..write(obj.updateDate)
      ..writeByte(5)
      ..write(obj.source)
      ..writeByte(6)
      ..write(obj.sourceName)
      ..writeByte(7)
      ..write(obj.categories)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.star);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicSimpleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ComicPageDataAdapter extends TypeAdapter<ComicPageData> {
  @override
  final int typeId = 4;

  @override
  ComicPageData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComicPageData(
      fields[0] as int,
      (fields[1] as List).cast<ComicSimple>(),
    );
  }

  @override
  void write(BinaryWriter writer, ComicPageData obj) {
    writer
      ..writeByte(2)
      ..writeByte(1)
      ..write(obj.records)
      ..writeByte(0)
      ..write(obj.pageCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicPageDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ImageInfoAdapter extends TypeAdapter<ImageInfo> {
  @override
  final int typeId = 5;

  @override
  ImageInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageInfo(
      fields[0] as String,
    )
      ..height = fields[1] as int?
      ..width = fields[2] as int?
      ..pid = fields[3] as String?;
  }

  @override
  void write(BinaryWriter writer, ImageInfo obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.src)
      ..writeByte(1)
      ..write(obj.height)
      ..writeByte(2)
      ..write(obj.width)
      ..writeByte(3)
      ..write(obj.pid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChapterAdapter extends TypeAdapter<Chapter> {
  @override
  final int typeId = 6;

  @override
  Chapter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chapter(
      fields[0] as String,
      fields[1] as String,
      fields[2] as int,
      (fields[3] as List).cast<ImageInfo>(),
    )
      ..uploadDate = fields[4] as String?
      ..scrambleId = fields[5] as int?
      ..aid = fields[6] as int?;
  }

  @override
  void write(BinaryWriter writer, Chapter obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.len)
      ..writeByte(3)
      ..write(obj.images)
      ..writeByte(4)
      ..write(obj.uploadDate)
      ..writeByte(5)
      ..write(obj.scrambleId)
      ..writeByte(6)
      ..write(obj.aid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ComicInfoAdapter extends TypeAdapter<ComicInfo> {
  @override
  final int typeId = 7;

  @override
  ComicInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ComicInfo(
      fields[0] as String,
      fields[1] as String,
      fields[2] as String,
      fields[4] as String,
      fields[3] as String,
      fields[5] as String,
      (fields[6] as List).cast<Chapter>(),
      fields[7] as String,
    )
      ..works = (fields[8] as List?)?.cast<String>()
      ..characters = (fields[9] as List?)?.cast<String>()
      ..authors = (fields[10] as List?)?.cast<String>()
      ..tags = (fields[11] as List?)?.cast<String>()
      ..star = fields[12] as String?
      ..views = fields[13] as String?
      ..state = fields[14] as ComicState?;
  }

  @override
  void write(BinaryWriter writer, ComicInfo obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.thumb)
      ..writeByte(3)
      ..write(obj.uploadDate)
      ..writeByte(4)
      ..write(obj.updateDate)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.chapters)
      ..writeByte(7)
      ..write(obj.author)
      ..writeByte(8)
      ..write(obj.works)
      ..writeByte(9)
      ..write(obj.characters)
      ..writeByte(10)
      ..write(obj.authors)
      ..writeByte(11)
      ..write(obj.tags)
      ..writeByte(12)
      ..write(obj.star)
      ..writeByte(13)
      ..write(obj.views)
      ..writeByte(14)
      ..write(obj.state);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ComicStateAdapter extends TypeAdapter<ComicState> {
  @override
  final int typeId = 1;

  @override
  ComicState read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ComicState.unknown;
      case 1:
        return ComicState.completed;
      case 2:
        return ComicState.ongoing;
      default:
        return ComicState.unknown;
    }
  }

  @override
  void write(BinaryWriter writer, ComicState obj) {
    switch (obj) {
      case ComicState.unknown:
        writer.writeByte(0);
        break;
      case ComicState.completed:
        writer.writeByte(1);
        break;
      case ComicState.ongoing:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReaderTypeAdapter extends TypeAdapter<ReaderType> {
  @override
  final int typeId = 8;

  @override
  ReaderType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReaderType.scroll;
      case 1:
        return ReaderType.album;
      default:
        return ReaderType.scroll;
    }
  }

  @override
  void write(BinaryWriter writer, ReaderType obj) {
    switch (obj) {
      case ReaderType.scroll:
        writer.writeByte(0);
        break;
      case ReaderType.album:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReaderDirectionAdapter extends TypeAdapter<ReaderDirection> {
  @override
  final int typeId = 9;

  @override
  ReaderDirection read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReaderDirection.topToBottom;
      case 1:
        return ReaderDirection.leftToRight;
      case 2:
        return ReaderDirection.rightToLeft;
      default:
        return ReaderDirection.topToBottom;
    }
  }

  @override
  void write(BinaryWriter writer, ReaderDirection obj) {
    switch (obj) {
      case ReaderDirection.topToBottom:
        writer.writeByte(0);
        break;
      case ReaderDirection.leftToRight:
        writer.writeByte(1);
        break;
      case ReaderDirection.rightToLeft:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderDirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
