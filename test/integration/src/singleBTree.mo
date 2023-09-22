import BTree            "../../../src/btree";
import BytesConverter   "../../../src/bytesConverter";

import Array            "mo:base/Array";
import Buffer           "mo:base/Buffer";
import Iter             "mo:base/Iter";

actor class SingleBTree() {

  // Arbitrary use of (Nat32, Text) for (key, value) types
  stable let _btree = BTree.new<Nat32, Text>(BTree.n32conv, BTree.t16conv);

  public func size() : async Nat {
    BTree.size(_btree);
  };

  public func put(key: Nat32, value: Text) : async ?Text {
    BTree.put(_btree,BTree.n32conv, key, BTree.t16conv, value);
  };

  public func get(key: Nat32) : async ?Text {
    BTree.get(_btree, BTree.n32conv, key, BTree.t16conv);
  };

  public func has(key: Nat32) : async Bool {
    BTree.has(_btree, BTree.n32conv, key);
  };

  public func empty() : async Bool {
    BTree.empty(_btree);
  };

  public func remove(key: Nat32) : async ?Text {
    BTree.remove(_btree, BTree.n32conv, key, BTree.t16conv);
  };

  public func insertMany(entries: [(Nat32, Text)]) : async () {
    for ((key, value) in Array.vals(entries)){
      ignore BTree.put(_btree, BTree.n32conv, key, BTree.t16conv, value);
    };
  };

  public func getMany(keys: [Nat32]) : async [Text] {
    let buffer = Buffer.Buffer<Text>(0);
    for (key in Array.vals(keys)){
      switch(BTree.get(_btree, BTree.n32conv, key, BTree.t16conv)){
        case(?value) { buffer.add(value); };
        case(null) {};
      };
    };
    Buffer.toArray(buffer);
  };

  public func hasKeys(keys: [Nat32]) : async Bool {
    for (key in Array.vals(keys)){
      if (not BTree.has(_btree, BTree.n32conv, key)){
        return false;
      };
    };
    return true;
  };

  public func removeMany(keys: [Nat32]) : async [Text] {
    let buffer = Buffer.Buffer<Text>(0);
    for (key in Array.vals(keys)){
      switch(BTree.remove(_btree, BTree.n32conv, key, BTree.t16conv)){
        case(?value) { buffer.add(value); };
        case(null) {};
      };
    };
    Buffer.toArray(buffer);
  };

  public func clear() : async () {
    let entries = Iter.toArray(BTree.iter(_btree, BTree.n32conv, BTree.t16conv));
    for ((key, _) in Array.vals(entries)){
      ignore BTree.remove(_btree, BTree.n32conv, key, BTree.t16conv);
    };
  };

};
