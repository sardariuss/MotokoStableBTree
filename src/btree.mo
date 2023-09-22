import Types          "types";
import BTreeMap       "btreemap";
import Memory         "memory";
import Conversion     "conversion";
import BytesConverter "bytesConverter";

import Iter           "mo:base/Iter";
import Nat            "mo:base/Nat";
import Region         "mo:base/Region";
import Debug          "mo:base/Debug";

import Nat64          "mo:base/Nat64";

module {

  type BytesConverter<T> = Types.BytesConverter<T>;

  // @todo: make all converters public here
  public let n32conv = BytesConverter.NAT32_CONVERTER;
  public let t16conv : BytesConverter<Text> = {
    from_bytes = Conversion.bytesToText;
    to_bytes = Conversion.textToBytes;
    max_size = 64;
    nonce = "";
  };

  type BTree<K, V> = {
    region: Region;
    key_nonce: K;
    value_nonce: V;
  };

  public func new<K, V>(key_converter: BytesConverter<K>, value_converter: BytesConverter<V>) : BTree<K, V> {
    let region = Region.new();
    // Need to init the BTree to store the max key and value size, also to make sure the load will work later
    ignore BTreeMap.new<K, V>(Memory.RegionMemory(region), key_converter, value_converter);
    { region; key_nonce = key_converter.nonce; value_nonce = value_converter.nonce; };
  };
  
  public func size<K, V>(btree: BTree<K, V>) : Nat { 
    let btreemap = loadBTreeMap<K, V>(btree);
    Nat64.toNat(btreemap.getLength());
  };

  public func put<K, V>(btree: BTree<K, V>, key_converter: BytesConverter<K>, key: K, value_converter: BytesConverter<V>, value: V) : ?V {
    let btreemap = loadBTreeMap<K, V>(btree);
    switch(btreemap.insert(key, key_converter, value, value_converter)){
      case(#err(#KeyTooLarge  ({ given; max; }))){ Debug.trap("The key is too large: { max = " # Nat.toText(max) # ", given = " # Nat.toText(given) # " }") };
      case(#err(#ValueTooLarge({ given; max; }))){ Debug.trap("The value is too large: { max = " # Nat.toText(max) # ", given = " # Nat.toText(given) # " }") };
      case(#ok(v)) { v; };
    };
  };

  public func get<K, V>(btree: BTree<K, V>, key_converter: BytesConverter<K>, key: K, value_converter: BytesConverter<V>) : ?V {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.get(key, key_converter, value_converter);
  };

  public func has<K, V>(btree: BTree<K, V>, key_converter: BytesConverter<K>, key: K) : Bool {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.containsKey(key, key_converter);
  };

  public func empty<K, V>(btree: BTree<K, V>) : Bool {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.isEmpty();
  };

  public func remove<K, V>(btree: BTree<K, V>, key_converter: BytesConverter<K>, key: K, value_converter: BytesConverter<V>) : ?V {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.remove(key, key_converter, value_converter);
  };

  public func iter<K, V>(btree: BTree<K, V>, key_converter: BytesConverter<K>, value_converter: BytesConverter<V>) : Iter.Iter<(K, V)> {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.iter(key_converter, value_converter);
  };

  public func range<K, V>(btree: BTree<K, V>, key_converter: BytesConverter<K>, value_converter: BytesConverter<V>, prefix: [Nat8], offset: ?[Nat8]) : Iter.Iter<(K, V)> {
    let btreemap = loadBTreeMap<K, V>(btree);
    btreemap.range(key_converter, value_converter, prefix, offset);
  };

  func loadBTreeMap<K, V>(btree: BTree<K, V>) : BTreeMap.BTreeMap<K, V> {
    let { region; key_nonce; value_nonce; } = btree;
    BTreeMap.load<K, V>(Memory.RegionMemory(region), key_nonce, value_nonce);
  };

};