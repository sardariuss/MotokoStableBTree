import StableBTree      "../../../src/btreemap";
import StableBTreeTypes "../../../src/types";
import Memory           "../../../src/memory";
import BytesConverter   "../../../src/bytesConverter";

import Result           "mo:base/Result";
import Array            "mo:base/Array";
import Buffer           "mo:base/Buffer";
import Iter             "mo:base/Iter";
import Nat              "mo:base/Nat";
import Nat32            "mo:base/Nat32";
import Trie             "mo:base/Trie";
import Region           "mo:base/Region";
import Debug            "mo:base/Debug";

actor class MultipleBTrees() {
  
  // For convenience: from StableBTree types
  type InsertError = StableBTreeTypes.InsertError;
  type BTreeId = Nat;
  
  // For convenience: from base module
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  // Arbitrary use of (Nat32, Text) for (key, value) types
  type K = Nat32;
  type V = Text;

  // Arbitrary limitation on text size (in bytes)
  let MAX_VALUE_SIZE : Nat32 = 100;

  // The regions used to store the BTreeMaps
  stable var _regions = Trie.empty<BTreeId, Region>();

  // Get BTreeMap identified with the btree_id if it exists
  func getBTreeMap(btree_id: BTreeId) : StableBTree.BTreeMap<K, V> {
    switch(Trie.get(_regions, { key = btree_id; hash = Nat32.fromNat(btree_id); }, Nat.equal)){
      case(null){ Debug.trap("Cannot find btree"); };
      case(?region){
        // Use init, so that the BTreeMap is created if it does not exist, otherwise it will just be loaded
        StableBTree.init<K, V>(Memory.RegionMemory(region), BytesConverter.NAT32_CONVERTER, BytesConverter.textConverter(MAX_VALUE_SIZE));
      };
    };
  };

  public func spawnBTree() : async BTreeId {
    let region = Region.new();
    let id = Region.id(region);
    _regions := Trie.put(_regions, { key = id; hash = Nat32.fromNat(id); }, Nat.equal, region).0;
    id;
  };

  public func getLength(btree_id: BTreeId) : async Nat64 {
    let btreemap = getBTreeMap(btree_id);
    btreemap.getLength();
  };

  public func insert(btree_id: BTreeId, key: K, value: V) : async Result<?V, InsertError> {
    let btreemap = getBTreeMap(btree_id);
    btreemap.insert(key, value);
  };

  public func get(btree_id: BTreeId, key: K) : async ?V {
    let btreemap = getBTreeMap(btree_id);
    btreemap.get(key);
  };

  public func containsKey(btree_id: BTreeId, key: K) : async Bool {
    let btreemap = getBTreeMap(btree_id);
    btreemap.containsKey(key);
  };

  public func isEmpty(btree_id: BTreeId) : async Bool {
    let btreemap = getBTreeMap(btree_id);
    btreemap.isEmpty();
  };

  public func remove(btree_id: BTreeId, key: K) : async ?V {
    let btreemap = getBTreeMap(btree_id);
    getBTreeMap(btree_id).remove(key);
  };

  public func insertMany(btree_id: BTreeId, entries: [(K, V)]) : async Result<(), [InsertError]> {
    let btreemap = getBTreeMap(btree_id);
    let buffer = Buffer.Buffer<InsertError>(0);
    for ((key, value) in Array.vals(entries)){
      switch(btreemap.insert(key, value)){
        case(#err(insert_error)) { buffer.add(insert_error); };
        case(_) {};
      };
    };
    if (buffer.size() > 0){
      #err(Buffer.toArray(buffer));
    } else {
      #ok;
    };
  };

  public func getMany(btree_id: BTreeId, keys: [K]) : async [V] {
    let btreemap = getBTreeMap(btree_id);
    let buffer = Buffer.Buffer<V>(0);
    for (key in Array.vals(keys)){
      switch(btreemap.get(key)){
        case(?value) { buffer.add(value); };
        case(null) {};
      };
    };
    Buffer.toArray(buffer);
  };

  public func containsKeys(btree_id: BTreeId, keys: [K]) : async Bool {
    let btreemap = getBTreeMap(btree_id);
    for (key in Array.vals(keys)){
      if (not btreemap.containsKey(key)) {
        return false;
      };
    };
    return true;
  };

  public func removeMany(btree_id: BTreeId, keys: [K]) : async [V] {
    let btreemap = getBTreeMap(btree_id);
    let buffer = Buffer.Buffer<V>(0);
    for (key in Array.vals(keys)){
      switch(btreemap.remove(key)){
        case(?value) { buffer.add(value); };
        case(null) {};
      };
    };
    Buffer.toArray(buffer);
  };

  public func empty(btree_id: BTreeId) : async () {
    let btreemap = getBTreeMap(btree_id);
    let entries = Iter.toArray(btreemap.iter());
    for ((key, _) in Array.vals(entries)){
      ignore btreemap.remove(key);
    };
  };

};
