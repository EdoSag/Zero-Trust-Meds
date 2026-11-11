import 'dart:typed_data';

import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/app/meds_config.dart';
import 'package:zerotrust_meds/data/meds_data.dart';

const mum = '00000000-0000-4000-8000-00000000000a';
const dad = '00000000-0000-4000-8000-00000000000b';
const sitter = '00000000-0000-4000-8000-00000000000c';

Uint8List dek(int seed) =>
    Uint8List.fromList(List<int>.generate(32, (i) => (seed * 7 + i) & 0xff));

/// One caregiver's phone, with Meds' rules for who may write what.
class Phone {
  Phone(this.server, this.userId, this.seed);
  final InMemorySpaceServer server;
  final String userId;
  final int seed;
  final Map<String, InMemoryItemStore> stores = {};
  late final SharedSpaces spaces;

  Future<Phone> start() async {
    spaces = SharedSpaces(
      app: 'meds',
      myUserId: userId,
      identity: await ZtIdentity.fromDek(dek(seed)),
      backend: server.backendFor(userId),
      privateStore: InMemorySpacePrivateStore(),
      openStore: (id) async => stores.putIfAbsent(id, InMemoryItemStore.new),
      deleteStore: (id) async => stores.remove(id),
      deviceId: 'phone-$userId',
      policy: medsSpacePolicy,
    );
    return this;
  }

  /// What the app shows for [spaceId] after syncing.
  Future<ChildData?> child(String spaceId) async {
    final space = await spaces.open(spaceId);
    await spaces.sync(space);
    final info = (await spaces.list()).firstWhere((i) => i.id == spaceId);
    return readChild(SpaceEntry(info: info, space: space));
  }
}
