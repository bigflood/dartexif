import "package:stream_channel/stream_channel.dart";
import 'test_util.dart';
import 'dart:convert';

hybridMain(StreamChannel channel) async {
  await for (var file in readSamples()) {
    channel.sink.add(JsonEncoder().convert(file));
  }

  channel.sink.close();
}
