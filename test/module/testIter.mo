import BTreeMap "../../src/btreemap";
import Node "../../src/node";
import Utils "../../src/utils";
import TestableItems "testableItems";

import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Order "mo:base/Order";

module {
  
  // For convenience: from base modules
  type Order = Order.Order;
  // For convenience: from other modules
  type TestBuffer = TestableItems.TestBuffer;

  /// Compare two bytes
  func bytesOrder(a: [Nat8], b: [Nat8]) : Order {
    Utils.lexicographicallyCompare(a, b, Nat8.compare);
  };
  
  func iterateLeaf(test: TestBuffer) {
    
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(0, Nat64.toNat(Node.getCapacity() - 1))){
      ignore btree.insert([Nat8.fromNat(i)], [Nat8.fromNat(i + 1)]);
    };

    var i : Nat8 = 0;
    for ((key, value) in btree.iter()){
      test.equalsBytes(key, [i]);
      test.equalsBytes(value, [i + 1]);
      i += 1;
    };

    test.equalsNat(Nat8.toNat(i), Nat64.toNat(Node.getCapacity()));
  };

  func iterateChildren(test: TestBuffer) {

    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    // Insert the elements in reverse order.
    for (i in Iter.revRange(99, 0)){
      ignore btree.insert([Nat8.fromNat(Int.abs(i))], [Nat8.fromNat(Int.abs(i + 1))]);
    };

    // Iteration should be in ascending order.
    var i : Nat8 = 0;
    for ((key, value) in btree.iter()){
      test.equalsBytes(key, [i]);
      test.equalsBytes(value, [i + 1]);
      i += 1;
    };

    test.equalsNat8(i, 100);
  };

  public func run() {
    let test = TestableItems.TestBuffer();

    iterateLeaf(test);
    iterateChildren(test);

    test.run("Test iter module");
  };

};