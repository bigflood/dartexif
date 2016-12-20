typedef String MakerTagFunc(List<int> list);

class MakerTag {
  String name;
  Map<int, String> map;
  MakerTagFunc func;
  MakerTagsWithName tags;

  MakerTag({this.name, this.map, this.func, this.tags});

  static MakerTag make(name) {
    return new MakerTag(name: name);
  }

  static MakerTag makeWithMap(name, map) {
    return new MakerTag(name: name, map: map);
  }

  static MakerTag makeWithFunc(name, MakerTagFunc func) {
    return new MakerTag(name: name, func: func);
  }

  static MakerTag makeWithTags(name, tags) {
    return new MakerTag(name: name, tags: tags);
  }
}

class MakerTagsWithName {
  String name;
  Map<int, MakerTag> tags;
  MakerTagsWithName({this.name, this.tags});
}

class tags_base {}
