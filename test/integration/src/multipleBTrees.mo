import BTree  "../../../src";

import Array  "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter   "mo:base/Iter";
import Nat    "mo:base/Nat";
import Nat32  "mo:base/Nat32";
import Trie   "mo:base/Trie";

actor class MultipleBTrees() {
  
  // For convenience
  type BTreeId = Nat;
  type BTree<K, V> = BTree.BTree<K, V>;

  let n32conv = BTree.n32conv;
  let t16conv = BTree.tconv(64); // Max 16 characters

  // Arbitrary use of (Nat32, Text) for (key, value) types
  stable var _btrees = Trie.empty<BTreeId, BTree<Nat32, Text>>();

  public func size(id: BTreeId) : async Nat {
    iterateBTree<Nat>(id, func(btree) = BTree.size(btree), 0);
  };

  public func put(id: BTreeId, key: Nat32, value: Text) : async ?Text {
    // Get the BTree with the given identifier if it exists, otherwise create it and add it to the trie
    let btree = switch(Trie.get(_btrees, { key = id; hash = Nat32.fromNat(id); }, Nat.equal)){
      case(?btree){ btree; };
      case(null){ 
        let btree = BTree.new<Nat32, Text>(n32conv, t16conv);
        _btrees := Trie.put(_btrees, { key = id; hash = Nat32.fromNat(id); }, Nat.equal, btree).0;
        btree;
      };
    };
    BTree.put(btree, n32conv, key, t16conv, value);
  };

  public func get(id: BTreeId, key: Nat32) : async ?Text {
    iterateBTree<?Text>(id, func(btree) = BTree.get(btree, n32conv, key, t16conv), null);
  };

  public func has(id: BTreeId, key: Nat32) : async Bool {
    iterateBTree<Bool>(id, func(btree) = BTree.has(btree, n32conv, key), false);
  };

  public func empty(id: BTreeId) : async Bool {
    iterateBTree<Bool>(id, func(btree) = BTree.empty(btree), true);
  };

  public func remove(id: BTreeId, key: Nat32) : async ?Text {
    iterateBTree<?Text>(id, func(btree) = BTree.remove(btree, n32conv, key, t16conv), null);
  };

  func iterateBTree<T>(id: BTreeId, fn: (BTree<Nat32, Text>) -> T, default: T) : T {
    switch(Trie.get(_btrees, { key = id; hash = Nat32.fromNat(id); }, Nat.equal)){
      case(?btree){ fn(btree); };
      case(null) { default; }
    };
  };

};
