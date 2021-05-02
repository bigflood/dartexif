typedef MakerTagFunc = String Function(List<int> list);

class MakerTag {
  String name;
  Map<int, String>? map;
  MakerTagFunc? func;
  MakerTagsWithName? tags;

  MakerTag.make(this.name);

  MakerTag.makeWithMap(this.name, this.map);

  MakerTag.makeWithFunc(this.name, this.func);

  MakerTag.makeWithTags(this.name, this.tags);
}

class MakerTagsWithName {
  String name;
  Map<int, MakerTag> tags;

  MakerTagsWithName({this.name = "", this.tags = const {}});
}

class TagsBase {}
