import Types            "../../src/modules/types";
import Memory           "../../src/modules/memory";
import BTreeMap         "../../src/modules/btreemap";
import Node             "../../src/modules/node";
import Utils            "../../src/modules/utils";
import Conversion       "../../src/modules/conversion";
import BytesConverter   "../../src/modules/bytesConverter";
import { Test }         "testableItems";

import { test; suite; } "mo:test";

import Nat64            "mo:base/Nat64";
import Nat32            "mo:base/Nat32";
import Nat8             "mo:base/Nat8";
import Iter             "mo:base/Iter";
import Int              "mo:base/Int";
import Blob             "mo:base/Blob";
import Array            "mo:base/Array";
import Buffer           "mo:base/Buffer";

suite("BTreemap test suite", func() {

  // For convenience: from base module
  type Iter<T> = Iter.Iter<T>;
  // For convenience: from types module
  type Entry = Types.Entry;
  // For convenience: from other modules
  type BTreeMap<K, V> = BTreeMap.BTreeMap<K, V>;

  let { n8aconv } = BytesConverter;

  // A helper method to succinctly create an entry.
  func e(x: Nat8) : Entry {
    (Blob.fromArray([x]), Blob.fromArray([]));
  };

  func toEntry(input: ([Nat8], [Nat8])) : Entry {
    (Blob.fromArray(input.0), Blob.fromArray(input.1));
  };

  func toEntryArray(input: [([Nat8], [Nat8])]) : [Entry] {
    Array.map(input, toEntry);
  };

  test("initPreservesData", func () {
    let mem = Memory.VecMemory();
    var btree = BTreeMap.init<[Nat8], [Nat8]>(mem, n8aconv(3), n8aconv(4));
    Test.equalsInsertResult(btree.insert([1, 2, 3], n8aconv(3), [4, 5, 6], n8aconv(4)), #ok(null)   );
    Test.equalsOptBytes    (btree.get   ([1, 2, 3], n8aconv(3),            n8aconv(4)), ?([4, 5, 6]));

    // Reload the btree
    btree := BTreeMap.init<[Nat8], [Nat8]>(mem, n8aconv(3), n8aconv(4));

    // Data still exists.
    Test.equalsOptBytes    (btree.get   ([1, 2, 3], n8aconv(3),            n8aconv(4)), ?([4, 5, 6]));
  });

  test("insertGet", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(3), n8aconv(4));
    Test.equalsInsertResult(btree.insert([1, 2, 3], n8aconv(3), [4, 5, 6], n8aconv(4)), #ok(null)   );
    Test.equalsOptBytes    (btree.get   ([1, 2, 3], n8aconv(3),            n8aconv(4)), ?([4, 5, 6]));
  });

  test("insertOverwritesPreviousValue", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));
    Test.equalsInsertResult(btree.insert([1, 2, 3], n8aconv(5), [4, 5, 6], n8aconv(5)), #ok(null)        );
    Test.equalsInsertResult(btree.insert([1, 2, 3], n8aconv(5), [7, 8, 9], n8aconv(5)), #ok(?([4, 5, 6])));
    Test.equalsOptBytes    (btree.get   ([1, 2, 3], n8aconv(5),            n8aconv(5)), ?([7, 8, 9])     );
  });

  test("insertGetMultiple", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));
    Test.equalsInsertResult(btree.insert([1, 2, 3], n8aconv(5), [4, 5, 6],     n8aconv(5)), #ok(null)       );
    Test.equalsInsertResult(btree.insert([4, 5],    n8aconv(5), [7, 8, 9, 10], n8aconv(5)), #ok(null)       );
    Test.equalsInsertResult(btree.insert([],        n8aconv(5), [11],          n8aconv(5)), #ok(null)       );
    Test.equalsOptBytes    (btree.get   ([1, 2, 3], n8aconv(5),                n8aconv(5)), ?([4, 5, 6])    );
    Test.equalsOptBytes    (btree.get   ([4, 5],    n8aconv(5),                n8aconv(5)), ?([7, 8, 9, 10]));
    Test.equalsOptBytes    (btree.get   ([],        n8aconv(5),                n8aconv(5)), ?([11])         );
  });

  test("insertOverwriteMedianKeyInFullChildNode", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 17)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]

    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(6)]);
    Test.equalsNat(root.getChildren().size(), 2);

    // The right child should now be full, with the median key being "12"
    var right_child = btree.loadNode(root.getChildren().get(1));
    Test.equalsBool(right_child.isFull(), true);
    let median_index = right_child.getEntries().size() / 2;
    Test.equalsBytes(Blob.toArray(right_child.getEntries().get(median_index).0), [12]);

    // Overwrite the median key.
    Test.equalsInsertResult(btree.insert([12], n8aconv(5), [1, 2, 3], n8aconv(5)), #ok(?([])));

    // The key is overwritten successfully.
    Test.equalsOptBytes(btree.get([12], n8aconv(5), n8aconv(5)), ?([1, 2, 3]));

    // The child has not been split and is still full.
    right_child := btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(right_child.getNodeType(), #Leaf);
    Test.equalsBool(right_child.isFull(), true);
  });

  test("insertOverwriteKeyInFullRootNode", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // We now have a root that is full and looks like this:
    //
    // [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsBool(root.isFull(), true);

    // Overwrite an element in the root. It should NOT cause the node to be split.
    Test.equalsInsertResult(btree.insert([6], n8aconv(5), [4, 5, 6], n8aconv(5)), #ok(?([])));

    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Leaf);
    Test.equalsOptBytes(btree.get([6], n8aconv(5), n8aconv(5)), ?([4, 5, 6]));
    Test.equalsNat(root.getEntries().size(), 11);
  });

  test("allocations", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));

    for (i in Iter.range(0, Nat64.toNat(Node.getCapacity() - 1))) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // Only need a single allocation to store up to `CAPACITY` elements.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);

    Test.equalsInsertResult(btree.insert([255], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The node had to be split into three nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);
  });

  test("allocations2", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 0);

    Test.equalsInsertResult(btree.insert([], n8aconv(5), [], n8aconv(5)), #ok(null));
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);

    Test.equalsOptBytes(btree.remove([], n8aconv(5), n8aconv(5)), ?([]));
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 0);
  });

  test("insertSameKeyMultiple", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));

    Test.equalsInsertResult(btree.insert([1], n8aconv(5), [2], n8aconv(5)), #ok(null));

    for (i in Iter.range(2, 9)) {
      Test.equalsInsertResult(btree.insert([1], n8aconv(5), [Nat8.fromNat(i) + 1], n8aconv(5)), #ok(?([Nat8.fromNat(i)])));
    };
  });

  test("insertSplitNode", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)], n8aconv(5), n8aconv(5)), ?([]));
    };
  });

  test("overwriteTest", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));

    let num_elements = 255;

    // Ensure that the number of elements we insert is significantly
    // higher than `CAPACITY` so that we test interesting cases (e.g.
    // overwriting the value in an internal node).
    assert(Nat64.fromNat(num_elements) > 10 * Node.getCapacity());

    for (i in Iter.range(0, num_elements - 1)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // Overwrite the values.
    for (i in Iter.range(0, num_elements - 1)) {
      // Assert we retrieved the old value correctly.
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [1, 2, 3], n8aconv(5)), #ok(?([])));
      // Assert we retrieved the new value correctly.
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)], n8aconv(5), n8aconv(5)), ?([1, 2, 3]));
    };
  });

  test("insertSplitMultipleNodes", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(6)]);
    Test.equalsNat(root.getChildren().size(), 2);

    var child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_0.getEntries()),
      [
        e(1),
        e(2),
        e(3),
        e(4),
        e(5),
      ]
    );

    var child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_1.getEntries()),
      [
        e(7),
        e(8),
        e(9),
        e(10),
        e(11),
        e(12),
      ]
    );

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)], n8aconv(5), n8aconv(5)), ?([]));
    };

    // Insert more to cause more splitting.
    Test.equalsInsertResult(btree.insert([13], n8aconv(5), [], n8aconv(5)), #ok(null));
    Test.equalsInsertResult(btree.insert([14], n8aconv(5), [], n8aconv(5)), #ok(null));
    Test.equalsInsertResult(btree.insert([15], n8aconv(5), [], n8aconv(5)), #ok(null));
    Test.equalsInsertResult(btree.insert([16], n8aconv(5), [], n8aconv(5)), #ok(null));
    Test.equalsInsertResult(btree.insert([17], n8aconv(5), [], n8aconv(5)), #ok(null));
    // Should cause another split
    Test.equalsInsertResult(btree.insert([18], n8aconv(5), [], n8aconv(5)), #ok(null));

    for (i in Iter.range(1, 18)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)], n8aconv(5), n8aconv(5)), ?([]));
    };

    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(6), e(12)]);
    Test.equalsNat(root.getChildren().size(), 3);

    child_0 := btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_0.getEntries()),
      [
        e(1),
        e(2),
        e(3),
        e(4),
        e(5),
      ]
    );

    child_1 := btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_1.getEntries()),
      [
        e(7),
        e(8),
        e(9),
        e(10),
        e(11),
      ]
    );

    let child_2 = btree.loadNode(root.getChildren().get(2));
    Test.equalsNodeType(child_2.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_2.getEntries()),
      [
        e(13),
        e(14),
        e(15),
        e(16),
        e(17),
        e(18),
      ]
    );
  });

  test("removeSimple", func(){
    let btree = BTreeMap.new<[Nat8], [Nat8]>(Memory.VecMemory(), n8aconv(5), n8aconv(5));

    Test.equalsInsertResult(btree.insert([1, 2, 3], n8aconv(5), [4, 5, 6], n8aconv(5)), #ok(null));
    Test.equalsOptBytes(btree.get([1, 2, 3], n8aconv(5), n8aconv(5)), ?([4, 5, 6]));
    Test.equalsOptBytes(btree.remove([1, 2, 3], n8aconv(5), n8aconv(5)), ?([4, 5, 6]));
    Test.equalsOptBytes(btree.get([1, 2, 3], n8aconv(5), n8aconv(5)), null);
  });

  test("removeCase2aAnd2c", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([0], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The result should look like this:
    //          [6]
    //           /   \
    // [0, 1, 2, 3, 4, 5]   [7, 8, 9, 10, 11]

    for (i in Iter.range(0, 11)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)], n8aconv(5), n8aconv(5)), ?([]));
    };

    // Remove node 6. Triggers case 2.a
    Test.equalsOptBytes(btree.remove([6], n8aconv(5), n8aconv(5)), ?([]));

    // The result should look like this:
    //        [5]
    //         /   \
    // [0, 1, 2, 3, 4]   [7, 8, 9, 10, 11]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(5)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_0.getEntries()), [e(0), e(1), e(2), e(3), e(4)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_1.getEntries()), [e(7), e(8), e(9), e(10), e(11)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);

    // Remove node 5. Triggers case 2c
    Test.equalsOptBytes(btree.remove([5], n8aconv(5), n8aconv(5)), ?([]));

    // Reload the btree to verify that we saved it correctly.
    btree := BTreeMap.load(mem, n8aconv(5), n8aconv(5));

    // The result should look like this:
    // [0, 1, 2, 3, 4, 7, 8, 9, 10, 11]
    root := btree.loadNode(btree.getRootAddr());
    Test.equalsEntries(
      Buffer.toArray(root.getEntries()),
      [e(0), e(1), e(2), e(3), e(4), e(7), e(8), e(9), e(10), e(11)]
    );

    // There is only one node allocated.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);
  });

  test("removeCase2b", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)], n8aconv(5), n8aconv(5)), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    Test.equalsOptBytes(btree.remove([6], n8aconv(5), n8aconv(5)), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(7)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_0.getEntries()), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_1.getEntries()), [e(8), e(9), e(10), e(11), e(12)]);

    // Remove node 7. Triggers case 2.c
    Test.equalsOptBytes(btree.remove([7], n8aconv(5), n8aconv(5)), ?([]));
    // The result should look like this:
    //
    // [1, 2, 3, 4, 5, 8, 9, 10, 11, 12]
    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(root.getEntries()),
      [
        e(1),
        e(2),
        e(3),
        e(4),
        e(5),
        e(8),
        e(9),
        e(10),
        e(11),
        e(12)
      ]
    );
  });

  test("removeCase3aRight", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    // Remove node 3. Triggers case 3.a
    Test.equalsOptBytes(btree.remove([3], n8aconv(5), n8aconv(5)), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 4, 5, 6]   [8, 9, 10, 11, 12]
    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(7)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_0.getEntries()), [e(1), e(2), e(4), e(5), e(6)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_1.getEntries()), [e(8), e(9), e(10), e(11), e(12)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);
  });

  test("removeCase3aLeft", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([0], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The result should look like this:
    //           [6]
    //          /   \
    // [0, 1, 2, 3, 4, 5]   [7, 8, 9, 10, 11]

    // Remove node 8. Triggers case 3.a left
    Test.equalsOptBytes(btree.remove([8], n8aconv(5), n8aconv(5)), ?([]));

    // The result should look like this:
    //        [5]
    //         /   \
    // [0, 1, 2, 3, 4]   [6, 7, 9, 10, 11]
    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(5)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_0.getEntries()), [e(0), e(1), e(2), e(3), e(4)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_1.getEntries()), [e(6), e(7), e(9), e(10), e(11)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);
  });

  test("removeCase3bMergeIntoRight", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)], n8aconv(5), n8aconv(5)), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    Test.equalsOptBytes(btree.remove([6], n8aconv(5), n8aconv(5)), ?([]));
    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(7)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_0.getEntries()), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_1.getEntries()), [e(8), e(9), e(10), e(11), e(12)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);

    // Remove node 3. Triggers case 3.b
    Test.equalsOptBytes(btree.remove([3], n8aconv(5), n8aconv(5)), ?([]));

    // Reload the btree to verify that we saved it correctly.
    btree := BTreeMap.load(mem, n8aconv(5), n8aconv(5));

    // The result should look like this:
    //
    // [1, 2, 4, 5, 7, 8, 9, 10, 11, 12]
    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(root.getEntries()),
      [
        e(1),
        e(2),
        e(4),
        e(5),
        e(7),
        e(8),
        e(9),
        e(10),
        e(11),
        e(12)
      ]
    );

    // There is only one allocated node remaining.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);
  });

  test("removeCase3bMergeIntoLeft", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], n8aconv(5), [], n8aconv(5)), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)], n8aconv(5), n8aconv(5)), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    Test.equalsOptBytes(btree.remove([6], n8aconv(5), n8aconv(5)), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [e(7)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_0.getEntries()), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(Buffer.toArray(child_1.getEntries()), [e(8), e(9), e(10), e(11), e(12)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);

    // Remove node 10. Triggers case 3.b where we merge the right into the left.
    Test.equalsOptBytes(btree.remove([10], n8aconv(5), n8aconv(5)), ?([]));

    // Reload the btree to verify that we saved it correctly.
    btree := BTreeMap.load(mem, n8aconv(5), n8aconv(5));

    // The result should look like this:
    //
    // [1, 2, 3, 4, 5, 7, 8, 9, 11, 12]
    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(root.getEntries()),
      [e(1), e(2), e(3), e(4), e(5), e(7), e(8), e(9), e(11), e(12)]
    );

    // There is only one allocated node remaining.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);
  });

  test("manyInsertions", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsInsertResult(btree.insert(bytes, n8aconv(5), bytes, n8aconv(5)), #ok(null));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.get(bytes, n8aconv(5), n8aconv(5)), ?(bytes));
      };
    };

    btree := BTreeMap.load(mem, n8aconv(5), n8aconv(5));

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.remove(bytes, n8aconv(5), n8aconv(5)), ?(bytes));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.get(bytes, n8aconv(5), n8aconv(5)), null);
      };
    };

    // We've deallocated everything.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 0);
  });

  test("manyInsertions2", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (j in Iter.revRange(10, 0)) {
      for (i in Iter.revRange(255, 0)) {
        let bytes = [Nat8.fromNat(Int.abs(i)), Nat8.fromNat(Int.abs(j))];
        Test.equalsInsertResult(btree.insert(bytes, n8aconv(5), bytes, n8aconv(5)), #ok(null));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.get(bytes, n8aconv(5), n8aconv(5)), ?(bytes));
      };
    };

    btree := BTreeMap.load(mem, n8aconv(5), n8aconv(5));

    for (j in Iter.revRange(10, 0)) {
      for (i in Iter.revRange((255, 0))) {
        let bytes = [Nat8.fromNat(Int.abs(i)), Nat8.fromNat(Int.abs(j))];
        Test.equalsOptBytes(btree.remove(bytes, n8aconv(5), n8aconv(5)), ?(bytes));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.get(bytes, n8aconv(5), n8aconv(5)), null);
      };
    };

    // We've deallocated everything.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 0);
  });

  test("reloading", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    // The btree is initially empty.
    Test.equalsNat64(btree.getLength(), 0);
    Test.equalsBool(btree.isEmpty(), true);

    // Add an entry into the btree.
    Test.equalsInsertResult(btree.insert([1, 2, 3], n8aconv(5), [4, 5, 6], n8aconv(5)) , #ok(null));
    Test.equalsNat64(btree.getLength(), 1);
    Test.equalsBool(btree.isEmpty(), false);

    // Reload the btree. The element should still be there, and `len()`
    // should still be `1`.
    btree := BTreeMap.load(mem, n8aconv(5), n8aconv(5));
    Test.equalsOptBytes(btree.get([1, 2, 3], n8aconv(5), n8aconv(5)), ?([4, 5, 6]));
    Test.equalsNat64(btree.getLength(), 1);
    Test.equalsBool(btree.isEmpty(), false);

    // Remove an element. Length should be zero.
    btree := BTreeMap.load(mem, n8aconv(5), n8aconv(5));
    Test.equalsOptBytes(btree.remove([1, 2, 3], n8aconv(5), n8aconv(5)), ?([4, 5, 6]));
    Test.equalsNat64(btree.getLength(), 0);
    Test.equalsBool(btree.isEmpty(), true);

    // Reload. Btree should still be empty.
    btree := BTreeMap.load(mem, n8aconv(5), n8aconv(5));
    Test.equalsOptBytes(btree.get([1, 2, 3], n8aconv(5), n8aconv(5)), null);
    Test.equalsNat64(btree.getLength(), 0);
    Test.equalsBool(btree.isEmpty(), true);
  });

  test("len", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (i in Iter.range(0, 999)) {
      Test.equalsInsertResult(btree.insert(Conversion.nat32ToByteArray(Nat32.fromNat(i)), n8aconv(5), [], n8aconv(5)) , #ok(null));
    };

    Test.equalsNat64(btree.getLength(), 1000);
    Test.equalsBool(btree.isEmpty(), false);

    for (i in Iter.range(0, 999)) {
      Test.equalsOptBytes(btree.remove(Conversion.nat32ToByteArray(Nat32.fromNat(i)), n8aconv(5), n8aconv(5)), ?([]));
    };

    Test.equalsNat64(btree.getLength(), 0);
    Test.equalsBool(btree.isEmpty(), true);
  });

  test("containsKey", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    // Insert even numbers from 0 to 1000.
    for (i in Iter.range(0, 499)) {
      Test.equalsInsertResult(btree.insert(Conversion.nat32ToByteArray(Nat32.fromNat(i * 2)), n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // Contains key should return true on all the even numbers and false on all the odd
    // numbers.
    for (i in Iter.range(0, 499)) {
      Test.equalsBool(btree.containsKey(Conversion.nat32ToByteArray(Nat32.fromNat(i)), n8aconv(5)), (i % 2 == 0));
    };
  });

  test("rangeEmpty", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    // Test prefixes that don't exist in the map.
    Test.equalsEntries(toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [0], null))), []);
    Test.equalsEntries(toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [1, 2, 3, 4], null))), []);
  });

  // Tests the case where the prefix is larger than all the entries in a leaf node.
  test("rangeLeafPrefixGreaterThanAllEntries", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    ignore btree.insert([0], n8aconv(5), [], n8aconv(5));

    // Test a prefix that's larger than the value in the leaf node. Should be empty.
    Test.equalsEntries(toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [1], null))), []);
  });

  // Tests the case where the prefix is larger than all the entries in an internal node.
  test("rangeInternalPrefixGreaterThanAllEntries", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    for (i in Iter.range(1, 12)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], n8aconv(5), [], n8aconv(5)), #ok(null));
    };

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    // Test a prefix that's larger than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [7], null))),
      [e(7)]
    );
  });

  test("rangeVariousPrefixes", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    ignore btree.insert([0, 1], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 2], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 3], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 4], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 1], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 2], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 3], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 4], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 1], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 2], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 3], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 4], n8aconv(5), [], n8aconv(5));

    // The result should look like this:
    //                     [(1, 2)]
    //                     /   \
    // [(0, 1), (0, 2), (0, 3), (0, 4), (1, 1)]     [(1, 3), (1, 4), (2, 1), (2, 2), (2, 3), (2, 4)]

    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [(Blob.fromArray([1, 2]), Blob.fromArray([]))]);
    Test.equalsNat(root.getChildren().size(), 2);

    // Tests a prefix that's smaller than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [0], null))),
      [
        (Blob.fromArray([0, 1]), Blob.fromArray([])),
        (Blob.fromArray([0, 2]), Blob.fromArray([])),
        (Blob.fromArray([0, 3]), Blob.fromArray([])),
        (Blob.fromArray([0, 4]), Blob.fromArray([])),
      ]
    );

    // Tests a prefix that crosses several nodes.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [1], null))),
      [
        (Blob.fromArray([1, 1]), Blob.fromArray([])),
        (Blob.fromArray([1, 2]), Blob.fromArray([])),
        (Blob.fromArray([1, 3]), Blob.fromArray([])),
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
      ]
    );

    // Tests a prefix that's larger than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [2], null))),
      [
        (Blob.fromArray([2, 1]), Blob.fromArray([])),
        (Blob.fromArray([2, 2]), Blob.fromArray([])),
        (Blob.fromArray([2, 3]), Blob.fromArray([])),
        (Blob.fromArray([2, 4]), Blob.fromArray([])),
      ]
    );
  });

  test("rangeVariousPrefixes2", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    ignore btree.insert([0, 1],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 2],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 3],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 4],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 2],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 4],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 6],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 8],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 10], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 1],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 2],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 3],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 4],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 5],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 6],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 7],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 8],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 9],  n8aconv(5), [], n8aconv(5));

    // The result should look like this:
    //                     [(1, 4), (2, 3)]
    //                     /    |     \
    // [(0, 1), (0, 2), (0, 3), (0, 4), (1, 2)]     |    [(2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9)]
    //                        |
    //               [(1, 6), (1, 8), (1, 10), (2, 1), (2, 2)]
    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(
      Buffer.toArray(root.getEntries()),
      [
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
        (Blob.fromArray([2, 3]), Blob.fromArray([])),
      ]
    );
    Test.equalsNat(root.getChildren().size(), 3);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_0.getEntries()),
      [
        (Blob.fromArray([0, 1]), Blob.fromArray([])),
        (Blob.fromArray([0, 2]), Blob.fromArray([])),
        (Blob.fromArray([0, 3]), Blob.fromArray([])),
        (Blob.fromArray([0, 4]), Blob.fromArray([])),
        (Blob.fromArray([1, 2]), Blob.fromArray([])),
      ]
    );

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_1.getEntries()),
      [
        (Blob.fromArray([1, 6]), Blob.fromArray([])),
        (Blob.fromArray([1, 8]), Blob.fromArray([])),
        (Blob.fromArray([1, 10]), Blob.fromArray([])),
        (Blob.fromArray([2, 1]), Blob.fromArray([])),
        (Blob.fromArray([2, 2]), Blob.fromArray([])),
      ]
    );

    let child_2 = btree.loadNode(root.getChildren().get(2));
    Test.equalsEntries(
      Buffer.toArray(child_2.getEntries()),
      [
        (Blob.fromArray([2, 4]), Blob.fromArray([])),
        (Blob.fromArray([2, 5]), Blob.fromArray([])),
        (Blob.fromArray([2, 6]), Blob.fromArray([])),
        (Blob.fromArray([2, 7]), Blob.fromArray([])),
        (Blob.fromArray([2, 8]), Blob.fromArray([])),
        (Blob.fromArray([2, 9]), Blob.fromArray([])),
      ]
    );

    // Tests a prefix that doesn't exist, but is in the middle of the root node.
    Test.equalsEntries(toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [1, 5], null))), []);

    // Tests a prefix that crosses several nodes.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [1], null))),
      [
        (Blob.fromArray([1, 2]), Blob.fromArray([])),
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
        (Blob.fromArray([1, 6]), Blob.fromArray([])),
        (Blob.fromArray([1, 8]), Blob.fromArray([])),
        (Blob.fromArray([1, 10]), Blob.fromArray([])),
      ]
    );

    // Tests a prefix that starts from a leaf node, then iterates through the root and right
    // sibling.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [2], null))),
      [
        (Blob.fromArray([2, 1]), Blob.fromArray([])),
        (Blob.fromArray([2, 2]), Blob.fromArray([])),
        (Blob.fromArray([2, 3]), Blob.fromArray([])),
        (Blob.fromArray([2, 4]), Blob.fromArray([])),
        (Blob.fromArray([2, 5]), Blob.fromArray([])),
        (Blob.fromArray([2, 6]), Blob.fromArray([])),
        (Blob.fromArray([2, 7]), Blob.fromArray([])),
        (Blob.fromArray([2, 8]), Blob.fromArray([])),
        (Blob.fromArray([2, 9]), Blob.fromArray([])),
      ]
    );
  });

  test("rangeLarge", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    // Insert 1000 elements with prefix 0 and another 1000 elements with prefix 1.
    for (prefix in Iter.range(0, 1)) {
      for (i in Iter.range(0, 999)) {
        // The key is the prefix followed by the integer's encoding.
        // The encoding is big-endian so that the byte representation of the
        // integers are sorted.
        let key = Utils.append([Nat8.fromNat(prefix)], Conversion.nat32ToByteArray(Nat32.fromNat(i)));
        Test.equalsInsertResult(btree.insert(key, n8aconv(5), [], n8aconv(5)), #ok(null));
      };
    };

    // Getting the range with a prefix should return all 1000 elements with that prefix.
    for (prefix in Iter.range(0, 1)) {
      var i : Nat32 = 0;
      for ((key, _) in btree.range(n8aconv(5), n8aconv(5), [Nat8.fromNat(prefix)], null)) {
        Test.equalsBytes(key, Utils.append([Nat8.fromNat(prefix)], Conversion.nat32ToByteArray(i)));
        i += 1;
      };
      Test.equalsNat32(i, 1000);
    };
  });

  test("rangeVariousPrefixesWithOffset", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    ignore btree.insert([0, 1], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 2], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 3], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 4], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 1], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 2], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 3], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 4], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 1], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 2], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 3], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 4], n8aconv(5), [], n8aconv(5));

    // The result should look like this:
    //                     [(1, 2)]
    //                     /   \
    // [(0, 1), (0, 2), (0, 3), (0, 4), (1, 1)]     [(1, 3), (1, 4), (2, 1), (2, 2), (2, 3), (2, 4)]

    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(Buffer.toArray(root.getEntries()), [(Blob.fromArray([1, 2]), Blob.fromArray([]))]);
    Test.equalsNat(root.getChildren().size(), 2);

    // Tests a offset that's smaller than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [0], ?([0])))),
      [
        (Blob.fromArray([0, 1]), Blob.fromArray([])),
        (Blob.fromArray([0, 2]), Blob.fromArray([])),
        (Blob.fromArray([0, 3]), Blob.fromArray([])),
        (Blob.fromArray([0, 4]), Blob.fromArray([])),
      ]
    );

    // Tests a offset that has a value somewhere in the range of values of an internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [1], ?([3])))),
      [
        (Blob.fromArray([1, 3]), Blob.fromArray([])), 
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
      ]
    );

    // Tests a offset that's larger than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [2], ?([5])))),
      [],
    );
  });

  test("rangeVariousPrefixesWithOffset2", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, n8aconv(5), n8aconv(5));

    ignore btree.insert([0, 1],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 2],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 3],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([0, 4],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 2],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 4],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 6],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 8],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([1, 10], n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 1],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 2],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 3],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 4],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 5],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 6],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 7],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 8],  n8aconv(5), [], n8aconv(5));
    ignore btree.insert([2, 9],  n8aconv(5), [], n8aconv(5));

    // The result should look like this:
    //                     [(1, 4), (2, 3)]
    //                     /    |     \
    // [(0, 1), (0, 2), (0, 3), (0, 4), (1, 2)]     |    [(2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9)]
    //                        |
    //               [(1, 6), (1, 8), (1, 10), (2, 1), (2, 2)]
    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(
      Buffer.toArray(root.getEntries()),
      [
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
        (Blob.fromArray([2, 3]), Blob.fromArray([])),
      ]
    );
    Test.equalsNat(root.getChildren().size(), 3);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_0.getEntries()),
      [
        (Blob.fromArray([0, 1]), Blob.fromArray([])),
        (Blob.fromArray([0, 2]), Blob.fromArray([])),
        (Blob.fromArray([0, 3]), Blob.fromArray([])),
        (Blob.fromArray([0, 4]), Blob.fromArray([])),
        (Blob.fromArray([1, 2]), Blob.fromArray([])),
      ]
    );

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(
      Buffer.toArray(child_1.getEntries()),
      [
        (Blob.fromArray([1, 6]), Blob.fromArray([])),
        (Blob.fromArray([1, 8]), Blob.fromArray([])),
        (Blob.fromArray([1, 10]), Blob.fromArray([])),
        (Blob.fromArray([2, 1]), Blob.fromArray([])),
        (Blob.fromArray([2, 2]), Blob.fromArray([])),
      ]
    );

    let child_2 = btree.loadNode(root.getChildren().get(2));
    Test.equalsEntries(
      Buffer.toArray(child_2.getEntries()),
      [
        (Blob.fromArray([2, 4]), Blob.fromArray([])),
        (Blob.fromArray([2, 5]), Blob.fromArray([])),
        (Blob.fromArray([2, 6]), Blob.fromArray([])),
        (Blob.fromArray([2, 7]), Blob.fromArray([])),
        (Blob.fromArray([2, 8]), Blob.fromArray([])),
        (Blob.fromArray([2, 9]), Blob.fromArray([])),
      ]
    );

    // Tests a offset that crosses several nodes.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [1], ?([4])))),
      [
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
        (Blob.fromArray([1, 6]), Blob.fromArray([])),
        (Blob.fromArray([1, 8]), Blob.fromArray([])),
        (Blob.fromArray([1, 10]), Blob.fromArray([])),
      ]
    );

    // Tests a offset that starts from a leaf node, then iterates through the root and right
    // sibling.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range(n8aconv(5), n8aconv(5), [2], ?([2])))),
      [
        (Blob.fromArray([2, 2]), Blob.fromArray([])),
        (Blob.fromArray([2, 3]), Blob.fromArray([])),
        (Blob.fromArray([2, 4]), Blob.fromArray([])),
        (Blob.fromArray([2, 5]), Blob.fromArray([])),
        (Blob.fromArray([2, 6]), Blob.fromArray([])),
        (Blob.fromArray([2, 7]), Blob.fromArray([])),
        (Blob.fromArray([2, 8]), Blob.fromArray([])),
        (Blob.fromArray([2, 9]), Blob.fromArray([])),
      ]
    );
  });

});