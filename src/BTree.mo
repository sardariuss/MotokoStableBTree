import Types          "modules/types";
import BTreeMap       "modules/btreemap";
import Memory         "modules/memory";
import BytesConverter "modules/bytesConverter";

import Iter           "mo:base/Iter";
import Nat            "mo:base/Nat";
import Region         "mo:base/Region";
import Debug          "mo:base/Debug";
import Nat64          "mo:base/Nat64";

module {

  type BytesConverter<T> = Types.BytesConverter<T>;

  public let { n8conv; n16conv; n32conv; n64conv; nconv; iconv; bconv; emptyconv; pconv; tconv; n8aconv; noconv; } = BytesConverter;

  public type BTree<K, V> = {
    region: Region;
    key_nonce: K;
    value_nonce: V;
  };

  public func new<K, V>(key_conv: BytesConverter<K>, value_conv: BytesConverter<V>) : BTree<K, V> {
    let region = Region.new();
    // Need to init the BTree to store the max key and value size, also to make sure the load will work later
    ignore BTreeMap.new<K, V>(Memory.RegionMemory(region), key_conv, value_conv);
    { region; key_nonce = key_conv.nonce; value_nonce = value_conv.nonce; };
  };
  
  public func size<K, V>(btree: BTree<K, V>) : Nat { 
    let btreemap = loadBTreeMap<K, V>(btree);
    Nat64.toNat(btreemap.getLength());
  };

  public func put<K, V>(btree: BTree<K, V>, key_conv: BytesConverter<K>, key: K, value_conv: BytesConverter<V>, value: V) : ?V {
    let btreemap = loadBTreeMap<K, V>(btree);
    switch(btreemap.insert(key, key_conv, value, value_conv)){
      case(#err(#KeyTooLarge  ({ given; max; }))){ Debug.trap("The key is too large: { max = " # Nat.toText(max) # ", given = " # Nat.toText(given) # " }") };
      case(#err(#ValueTooLarge({ given; max; }))){ Debug.trap("The value is too large: { max = " # Nat.toText(max) # ", given = " # Nat.toText(given) # " }") };
      case(#ok(v)) { v; };
    };
  };

  public func get<K, V>(btree: BTree<K, V>, key_conv: BytesConverter<K>, key: K, value_conv: BytesConverter<V>) : ?V {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.get(key, key_conv, value_conv);
  };

  public func has<K, V>(btree: BTree<K, V>, key_conv: BytesConverter<K>, key: K) : Bool {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.containsKey(key, key_conv);
  };

  public func empty<K, V>(btree: BTree<K, V>) : Bool {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.isEmpty();
  };

  public func remove<K, V>(btree: BTree<K, V>, key_conv: BytesConverter<K>, key: K, value_conv: BytesConverter<V>) : ?V {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.remove(key, key_conv, value_conv);
  };

  public func iter<K, V>(btree: BTree<K, V>, key_conv: BytesConverter<K>, value_conv: BytesConverter<V>) : Iter.Iter<(K, V)> {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.iter(key_conv, value_conv);
  };

  public func range<K, V>(btree: BTree<K, V>, key_conv: BytesConverter<K>, value_conv: BytesConverter<V>, prefix: [Nat8], offset: ?[Nat8]) : Iter.Iter<(K, V)> {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.range(key_conv, value_conv, prefix, offset);
  };

  func loadBTreeMap<K, V>(btree: BTree<K, V>) : BTreeMap.BTreeMap<K, V> {
    let { region; key_nonce; value_nonce; } = btree;
    BTreeMap.load<K, V>(Memory.RegionMemory(region), { nonce = key_nonce }, { nonce = value_nonce });
  };

};