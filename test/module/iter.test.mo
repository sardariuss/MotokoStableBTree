import Memory           "../../src/memory";
import BTreeMap         "../../src/btreemap";
import Node             "../../src/node";
import BytesConverter   "../../src/bytesConverter";
import { Test }         "testableItems";

import { test; suite; } "mo:test";

import Iter             "mo:base/Iter";
import Nat64            "mo:base/Nat64";
import Nat8             "mo:base/Nat8";
import Int              "mo:base/Int";

suite("Iter test suite", func() {

  test("iterateLeaf", func(){

    // Iterate on leaf
    let memory = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(memory, BytesConverter.byteArrayConverter(1), BytesConverter.byteArrayConverter(1));

    for (i in Iter.range(0, Nat64.toNat(Node.getCapacity() - 1))){
      ignore btree.insert([Nat8.fromNat(i)], [Nat8.fromNat(i + 1)]);
    };

    var i : Nat8 = 0;
    for ((key, value) in btree.iter()){
      Test.equalsBytes(key, [i]);
      Test.equalsBytes(value, [i + 1]);
      i += 1;
    };

    Test.equalsNat(Nat8.toNat(i), Nat64.toNat(Node.getCapacity()));
  });

  test("iterateChildren", func(){

    // Iterate on leaf
    let memory = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(memory, BytesConverter.byteArrayConverter(1), BytesConverter.byteArrayConverter(1));

    // Insert the elements in reverse order.
    for (i in Iter.revRange(99, 0)){
      ignore btree.insert([Nat8.fromNat(Int.abs(i))], [Nat8.fromNat(Int.abs(i + 1))]);
    };

    // Iteration should be in ascending order.
    var i : Nat8 = 0;
    for ((key, value) in btree.iter()){
      Test.equalsBytes(key, [i]);
      Test.equalsBytes(value, [i + 1]);
      i += 1;
    };

    Test.equalsNat8(i, 100);
  });

});