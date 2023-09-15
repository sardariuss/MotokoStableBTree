import Types            "../../src/types";
import Memory           "../../src/memory";
import BTreeMap         "../../src/btreemap";
import Node             "../../src/node";
import Utils            "../../src/utils";
import Conversion       "../../src/conversion";
import BytesConverter   "../../src/bytesConverter";
import { Test }         "testableItems";

import { test; suite; } "mo:test";

import Nat64            "mo:base/Nat64";
import Nat32            "mo:base/Nat32";
import Nat8             "mo:base/Nat8";
import Iter             "mo:base/Iter";
import Int              "mo:base/Int";
import Blob             "mo:base/Blob";
import Array            "mo:base/Array";

suite("BTreemap test suite", func() {

  // For convenience: from base module
  type Iter<T> = Iter.Iter<T>;
  // For convenience: from types module
  type Entry = Types.Entry;
  // For convenience: from other modules
  type BTreeMap<K, V> = BTreeMap.BTreeMap<K, V>;

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
    var btree = BTreeMap.init<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(3), BytesConverter.byteArrayConverter(4));
    Test.equalsInsertResult(btree.insert([1, 2, 3], [4, 5, 6]), #ok(null));
    Test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));

    // Reload the btree
    btree := BTreeMap.init<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(3), BytesConverter.byteArrayConverter(4));

    // Data still exists.
    Test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));
  });

  test("insertGet", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(3), BytesConverter.byteArrayConverter(4));

    Test.equalsInsertResult(btree.insert([1, 2, 3], [4, 5, 6]), #ok(null));
    Test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));
  });

  test("insertOverwritesPreviousValue", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    Test.equalsInsertResult(btree.insert([1, 2, 3], [4, 5, 6]), #ok(null));
    Test.equalsInsertResult(btree.insert([1, 2, 3], [7, 8, 9]), #ok(?([4, 5, 6])));
    Test.equalsOptBytes(btree.get([1, 2, 3]), ?([7, 8, 9]));
  });

  test("insertGetMultiple", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    Test.equalsInsertResult(btree.insert([1, 2, 3] , [4, 5, 6]), #ok(null));
    Test.equalsInsertResult(btree.insert([4, 5] , [7, 8, 9, 10]), #ok(null));
    Test.equalsInsertResult(btree.insert([], [11]), #ok(null));
    Test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));
    Test.equalsOptBytes(btree.get([4, 5]), ?([7, 8, 9, 10]));
    Test.equalsOptBytes(btree.get([]), ?([11]));
  });

  test("insertOverwriteMedianKeyInFullChildNode", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 17)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]

    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(6)]);
    Test.equalsNat(root.getChildren().size(), 2);

    // The right child should now be full, with the median key being "12"
    var right_child = btree.loadNode(root.getChildren().get(1));
    Test.equalsBool(right_child.isFull(), true);
    let median_index = right_child.getEntries().size() / 2;
    Test.equalsBytes(Blob.toArray(right_child.getEntries().get(median_index).0), [12]);

    // Overwrite the median key.
    Test.equalsInsertResult(btree.insert([12], [1, 2, 3]), #ok(?([])));

    // The key is overwritten successfully.
    Test.equalsOptBytes(btree.get([12]), ?([1, 2, 3]));

    // The child has not been split and is still full.
    right_child := btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(right_child.getNodeType(), #Leaf);
    Test.equalsBool(right_child.isFull(), true);
  });

  test("insertOverwriteKeyInFullRootNode", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };

    // We now have a root that is full and looks like this:
    //
    // [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsBool(root.isFull(), true);

    // Overwrite an element in the root. It should NOT cause the node to be split.
    Test.equalsInsertResult(btree.insert([6], [4, 5, 6]), #ok(?([])));

    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Leaf);
    Test.equalsOptBytes(btree.get([6]), ?([4, 5, 6]));
    Test.equalsNat(root.getEntries().size(), 11);
  });

  test("allocations", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(0, Nat64.toNat(Node.getCapacity() - 1))) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };

    // Only need a single allocation to store up to `CAPACITY` elements.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);

    Test.equalsInsertResult(btree.insert([255], []), #ok(null));

    // The node had to be split into three nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);
  });

  test("allocations2", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 0);

    Test.equalsInsertResult(btree.insert([], []), #ok(null));
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);

    Test.equalsOptBytes(btree.remove([]), ?([]));
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 0);
  });

  test("insertSameKeyMultiple", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    Test.equalsInsertResult(btree.insert([1], [2]), #ok(null));

    for (i in Iter.range(2, 9)) {
      Test.equalsInsertResult(btree.insert([1], [Nat8.fromNat(i) + 1]), #ok(?([Nat8.fromNat(i)])));
    };
  });

  test("insertSplitNode", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };

    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], []), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };
  });

  test("overwriteTest", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    let num_elements = 255;

    // Ensure that the number of elements we insert is significantly
    // higher than `CAPACITY` so that we test interesting cases (e.g.
    // overwriting the value in an internal node).
    assert(Nat64.fromNat(num_elements) > 10 * Node.getCapacity());

    for (i in Iter.range(0, num_elements - 1)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };

    // Overwrite the values.
    for (i in Iter.range(0, num_elements - 1)) {
      // Assert we retrieved the old value correctly.
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], [1, 2, 3]), #ok(?([])));
      // Assert we retrieved the new value correctly.
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([1, 2, 3]));
    };
  });

  test("insertSplitMultipleNodes", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], []), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(6)]);
    Test.equalsNat(root.getChildren().size(), 2);

    var child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(
      child_0.getEntries().toArray(),
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
      child_1.getEntries().toArray(),
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
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Insert more to cause more splitting.
    Test.equalsInsertResult(btree.insert([13], []), #ok(null));
    Test.equalsInsertResult(btree.insert([14], []), #ok(null));
    Test.equalsInsertResult(btree.insert([15], []), #ok(null));
    Test.equalsInsertResult(btree.insert([16], []), #ok(null));
    Test.equalsInsertResult(btree.insert([17], []), #ok(null));
    // Should cause another split
    Test.equalsInsertResult(btree.insert([18], []), #ok(null));

    for (i in Iter.range(1, 18)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(6), e(12)]);
    Test.equalsNat(root.getChildren().size(), 3);

    child_0 := btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(
      child_0.getEntries().toArray(),
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
      child_1.getEntries().toArray(),
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
      child_2.getEntries().toArray(),
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
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    Test.equalsInsertResult(btree.insert([1, 2, 3], [4, 5, 6]), #ok(null));
    Test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));
    Test.equalsOptBytes(btree.remove([1, 2, 3]), ?([4, 5, 6]));
    Test.equalsOptBytes(btree.get([1, 2, 3]), null);
  });

  test("removeCase2aAnd2c", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([0], []), #ok(null));

    // The result should look like this:
    //          [6]
    //           /   \
    // [0, 1, 2, 3, 4, 5]   [7, 8, 9, 10, 11]

    for (i in Iter.range(0, 11)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Remove node 6. Triggers case 2.a
    Test.equalsOptBytes(btree.remove([6]), ?([]));

    // The result should look like this:
    //        [5]
    //         /   \
    // [0, 1, 2, 3, 4]   [7, 8, 9, 10, 11]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(5)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(child_0.getEntries().toArray(), [e(0), e(1), e(2), e(3), e(4)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(child_1.getEntries().toArray(), [e(7), e(8), e(9), e(10), e(11)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);

    // Remove node 5. Triggers case 2c
    Test.equalsOptBytes(btree.remove([5]), ?([]));

    // Reload the btree to verify that we saved it correctly.
    btree := BTreeMap.load(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    // The result should look like this:
    // [0, 1, 2, 3, 4, 7, 8, 9, 10, 11]
    root := btree.loadNode(btree.getRootAddr());
    Test.equalsEntries(
      root.getEntries().toArray(),
      [e(0), e(1), e(2), e(3), e(4), e(7), e(8), e(9), e(10), e(11)]
    );

    // There is only one node allocated.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);
  });

  test("removeCase2b", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], []), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    Test.equalsOptBytes(btree.remove([6]), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(7)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(child_0.getEntries().toArray(), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(child_1.getEntries().toArray(), [e(8), e(9), e(10), e(11), e(12)]);

    // Remove node 7. Triggers case 2.c
    Test.equalsOptBytes(btree.remove([7]), ?([]));
    // The result should look like this:
    //
    // [1, 2, 3, 4, 5, 8, 9, 10, 11, 12]
    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Leaf);
    Test.equalsEntries(
      root.getEntries().toArray(),
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
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };

    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], []), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    // Remove node 3. Triggers case 3.a
    Test.equalsOptBytes(btree.remove([3]), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 4, 5, 6]   [8, 9, 10, 11, 12]
    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(7)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(child_0.getEntries().toArray(), [e(1), e(2), e(4), e(5), e(6)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(child_1.getEntries().toArray(), [e(8), e(9), e(10), e(11), e(12)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);
  });

  test("removeCase3aLeft", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([0], []), #ok(null));

    // The result should look like this:
    //           [6]
    //          /   \
    // [0, 1, 2, 3, 4, 5]   [7, 8, 9, 10, 11]

    // Remove node 8. Triggers case 3.a left
    Test.equalsOptBytes(btree.remove([8]), ?([]));

    // The result should look like this:
    //        [5]
    //         /   \
    // [0, 1, 2, 3, 4]   [6, 7, 9, 10, 11]
    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(5)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(child_0.getEntries().toArray(), [e(0), e(1), e(2), e(3), e(4)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(child_1.getEntries().toArray(), [e(6), e(7), e(9), e(10), e(11)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);
  });

  test("removeCase3bMergeIntoRight", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };
    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], []), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    Test.equalsOptBytes(btree.remove([6]), ?([]));
    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(7)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(child_0.getEntries().toArray(), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(child_1.getEntries().toArray(), [e(8), e(9), e(10), e(11), e(12)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);

    // Remove node 3. Triggers case 3.b
    Test.equalsOptBytes(btree.remove([3]), ?([]));

    // Reload the btree to verify that we saved it correctly.
    btree := BTreeMap.load(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    // The result should look like this:
    //
    // [1, 2, 4, 5, 7, 8, 9, 10, 11, 12]
    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Leaf);
    Test.equalsEntries(
      root.getEntries().toArray(),
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
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 11)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };

    // Should now split a node.
    Test.equalsInsertResult(btree.insert([12], []), #ok(null));

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      Test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    Test.equalsOptBytes(btree.remove([6]), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [e(7)]);
    Test.equalsNat(root.getChildren().size(), 2);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(child_0.getEntries().toArray(), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = btree.loadNode(root.getChildren().get(1));
    Test.equalsNodeType(child_1.getNodeType(), #Leaf);
    Test.equalsEntries(child_1.getEntries().toArray(), [e(8), e(9), e(10), e(11), e(12)]);

    // There are three allocated nodes.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 3);

    // Remove node 10. Triggers case 3.b where we merge the right into the left.
    Test.equalsOptBytes(btree.remove([10]), ?([]));

    // Reload the btree to verify that we saved it correctly.
    btree := BTreeMap.load(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    // The result should look like this:
    //
    // [1, 2, 3, 4, 5, 7, 8, 9, 11, 12]
    root := btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Leaf);
    Test.equalsEntries(
      root.getEntries().toArray(),
      [e(1), e(2), e(3), e(4), e(5), e(7), e(8), e(9), e(11), e(12)]
    );

    // There is only one allocated node remaining.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 1);
  });

  test("manyInsertions", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsInsertResult(btree.insert(bytes, bytes), #ok(null));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.get(bytes), ?(bytes));
      };
    };

    btree := BTreeMap.load(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.remove(bytes), ?(bytes));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.get(bytes), null);
      };
    };

    // We've deallocated everything.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 0);
  });

  test("manyInsertions2", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (j in Iter.revRange(10, 0)) {
      for (i in Iter.revRange(255, 0)) {
        let bytes = [Nat8.fromNat(Int.abs(i)), Nat8.fromNat(Int.abs(j))];
        Test.equalsInsertResult(btree.insert(bytes, bytes), #ok(null));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.get(bytes), ?(bytes));
      };
    };

    btree := BTreeMap.load(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (j in Iter.revRange(10, 0)) {
      for (i in Iter.revRange((255, 0))) {
        let bytes = [Nat8.fromNat(Int.abs(i)), Nat8.fromNat(Int.abs(j))];
        Test.equalsOptBytes(btree.remove(bytes), ?(bytes));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        Test.equalsOptBytes(btree.get(bytes), null);
      };
    };

    // We've deallocated everything.
    Test.equalsNat64(btree.getAllocator().getNumAllocatedChunks(), 0);
  });

  test("reloading", func(){
    let mem = Memory.VecMemory();
    var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    // The btree is initially empty.
    Test.equalsNat64(btree.getLength(), 0);
    Test.equalsBool(btree.isEmpty(), true);

    // Add an entry into the btree.
    Test.equalsInsertResult(btree.insert([1, 2, 3], [4, 5, 6]) , #ok(null));
    Test.equalsNat64(btree.getLength(), 1);
    Test.equalsBool(btree.isEmpty(), false);

    // Reload the btree. The element should still be there, and `len()`
    // should still be `1`.
    btree := BTreeMap.load(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));
    Test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));
    Test.equalsNat64(btree.getLength(), 1);
    Test.equalsBool(btree.isEmpty(), false);

    // Remove an element. Length should be zero.
    btree := BTreeMap.load(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));
    Test.equalsOptBytes(btree.remove([1, 2, 3]), ?([4, 5, 6]));
    Test.equalsNat64(btree.getLength(), 0);
    Test.equalsBool(btree.isEmpty(), true);

    // Reload. Btree should still be empty.
    btree := BTreeMap.load(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));
    Test.equalsOptBytes(btree.get([1, 2, 3]), null);
    Test.equalsNat64(btree.getLength(), 0);
    Test.equalsBool(btree.isEmpty(), true);
  });

  test("len", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(0, 999)) {
      Test.equalsInsertResult(btree.insert(Conversion.nat32ToByteArray(Nat32.fromNat(i)), []) , #ok(null));
    };

    Test.equalsNat64(btree.getLength(), 1000);
    Test.equalsBool(btree.isEmpty(), false);

    for (i in Iter.range(0, 999)) {
      Test.equalsOptBytes(btree.remove(Conversion.nat32ToByteArray(Nat32.fromNat(i))), ?([]));
    };

    Test.equalsNat64(btree.getLength(), 0);
    Test.equalsBool(btree.isEmpty(), true);
  });

  test("containsKey", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    // Insert even numbers from 0 to 1000.
    for (i in Iter.range(0, 499)) {
      Test.equalsInsertResult(btree.insert(Conversion.nat32ToByteArray(Nat32.fromNat(i * 2)), []), #ok(null));
    };

    // Contains key should return true on all the even numbers and false on all the odd
    // numbers.
    for (i in Iter.range(0, 499)) {
      Test.equalsBool(btree.containsKey(Conversion.nat32ToByteArray(Nat32.fromNat(i))), (i % 2 == 0));
    };
  });

  test("rangeEmpty", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    // Test prefixes that don't exist in the map.
    Test.equalsEntries(toEntryArray(Iter.toArray(btree.range([0], null))), []);
    Test.equalsEntries(toEntryArray(Iter.toArray(btree.range([1, 2, 3, 4], null))), []);
  });

  // Tests the case where the prefix is larger than all the entries in a leaf node.
  test("rangeLeafPrefixGreaterThanAllEntries", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    ignore btree.insert([0], []);

    // Test a prefix that's larger than the value in the leaf node. Should be empty.
    Test.equalsEntries(toEntryArray(Iter.toArray(btree.range([1], null))), []);
  });

  // Tests the case where the prefix is larger than all the entries in an internal node.
  test("rangeInternalPrefixGreaterThanAllEntries", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    for (i in Iter.range(1, 12)) {
      Test.equalsInsertResult(btree.insert([Nat8.fromNat(i)], []), #ok(null));
    };

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    // Test a prefix that's larger than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range([7], null))),
      [e(7)]
    );
  });

  test("rangeVariousPrefixes", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    ignore btree.insert([0, 1], []);
    ignore btree.insert([0, 2], []);
    ignore btree.insert([0, 3], []);
    ignore btree.insert([0, 4], []);
    ignore btree.insert([1, 1], []);
    ignore btree.insert([1, 2], []);
    ignore btree.insert([1, 3], []);
    ignore btree.insert([1, 4], []);
    ignore btree.insert([2, 1], []);
    ignore btree.insert([2, 2], []);
    ignore btree.insert([2, 3], []);
    ignore btree.insert([2, 4], []);

    // The result should look like this:
    //                     [(1, 2)]
    //                     /   \
    // [(0, 1), (0, 2), (0, 3), (0, 4), (1, 1)]     [(1, 3), (1, 4), (2, 1), (2, 2), (2, 3), (2, 4)]

    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [(Blob.fromArray([1, 2]), Blob.fromArray([]))]);
    Test.equalsNat(root.getChildren().size(), 2);

    // Tests a prefix that's smaller than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range([0], null))),
      [
        (Blob.fromArray([0, 1]), Blob.fromArray([])),
        (Blob.fromArray([0, 2]), Blob.fromArray([])),
        (Blob.fromArray([0, 3]), Blob.fromArray([])),
        (Blob.fromArray([0, 4]), Blob.fromArray([])),
      ]
    );

    // Tests a prefix that crosses several nodes.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range([1], null))),
      [
        (Blob.fromArray([1, 1]), Blob.fromArray([])),
        (Blob.fromArray([1, 2]), Blob.fromArray([])),
        (Blob.fromArray([1, 3]), Blob.fromArray([])),
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
      ]
    );

    // Tests a prefix that's larger than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range([2], null))),
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
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    ignore btree.insert([0, 1],  []);
    ignore btree.insert([0, 2],  []);
    ignore btree.insert([0, 3],  []);
    ignore btree.insert([0, 4],  []);
    ignore btree.insert([1, 2],  []);
    ignore btree.insert([1, 4],  []);
    ignore btree.insert([1, 6],  []);
    ignore btree.insert([1, 8],  []);
    ignore btree.insert([1, 10], []);
    ignore btree.insert([2, 1],  []);
    ignore btree.insert([2, 2],  []);
    ignore btree.insert([2, 3],  []);
    ignore btree.insert([2, 4],  []);
    ignore btree.insert([2, 5],  []);
    ignore btree.insert([2, 6],  []);
    ignore btree.insert([2, 7],  []);
    ignore btree.insert([2, 8],  []);
    ignore btree.insert([2, 9],  []);

    // The result should look like this:
    //                     [(1, 4), (2, 3)]
    //                     /    |     \
    // [(0, 1), (0, 2), (0, 3), (0, 4), (1, 2)]     |    [(2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9)]
    //                        |
    //               [(1, 6), (1, 8), (1, 10), (2, 1), (2, 2)]
    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(
      root.getEntries().toArray(),
      [
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
        (Blob.fromArray([2, 3]), Blob.fromArray([])),
      ]
    );
    Test.equalsNat(root.getChildren().size(), 3);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(
      child_0.getEntries().toArray(),
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
      child_1.getEntries().toArray(),
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
      child_2.getEntries().toArray(),
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
    Test.equalsEntries(toEntryArray(Iter.toArray(btree.range([1, 5], null))), []);

    // Tests a prefix that crosses several nodes.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range([1], null))),
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
      toEntryArray(Iter.toArray(btree.range([2], null))),
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
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    // Insert 1000 elements with prefix 0 and another 1000 elements with prefix 1.
    for (prefix in Iter.range(0, 1)) {
      for (i in Iter.range(0, 999)) {
        // The key is the prefix followed by the integer's encoding.
        // The encoding is big-endian so that the byte representation of the
        // integers are sorted.
        let key = Utils.append([Nat8.fromNat(prefix)], Conversion.nat32ToByteArray(Nat32.fromNat(i)));
        Test.equalsInsertResult(btree.insert(key, []), #ok(null));
      };
    };

    // Getting the range with a prefix should return all 1000 elements with that prefix.
    for (prefix in Iter.range(0, 1)) {
      var i : Nat32 = 0;
      for ((key, _) in btree.range([Nat8.fromNat(prefix)], null)) {
        Test.equalsBytes(key, Utils.append([Nat8.fromNat(prefix)], Conversion.nat32ToByteArray(i)));
        i += 1;
      };
      Test.equalsNat32(i, 1000);
    };
  });

  test("rangeVariousPrefixesWithOffset", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    ignore btree.insert([0, 1], []);
    ignore btree.insert([0, 2], []);
    ignore btree.insert([0, 3], []);
    ignore btree.insert([0, 4], []);
    ignore btree.insert([1, 1], []);
    ignore btree.insert([1, 2], []);
    ignore btree.insert([1, 3], []);
    ignore btree.insert([1, 4], []);
    ignore btree.insert([2, 1], []);
    ignore btree.insert([2, 2], []);
    ignore btree.insert([2, 3], []);
    ignore btree.insert([2, 4], []);

    // The result should look like this:
    //                     [(1, 2)]
    //                     /   \
    // [(0, 1), (0, 2), (0, 3), (0, 4), (1, 1)]     [(1, 3), (1, 4), (2, 1), (2, 2), (2, 3), (2, 4)]

    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(root.getEntries().toArray(), [(Blob.fromArray([1, 2]), Blob.fromArray([]))]);
    Test.equalsNat(root.getChildren().size(), 2);

    // Tests a offset that's smaller than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range([0], ?([0])))),
      [
        (Blob.fromArray([0, 1]), Blob.fromArray([])),
        (Blob.fromArray([0, 2]), Blob.fromArray([])),
        (Blob.fromArray([0, 3]), Blob.fromArray([])),
        (Blob.fromArray([0, 4]), Blob.fromArray([])),
      ]
    );

    // Tests a offset that has a value somewhere in the range of values of an internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range([1], ?([3])))),
      [
        (Blob.fromArray([1, 3]), Blob.fromArray([])), 
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
      ]
    );

    // Tests a offset that's larger than the value in the internal node.
    Test.equalsEntries(
      toEntryArray(Iter.toArray(btree.range([2], ?([5])))),
      [],
    );
  });

  test("rangeVariousPrefixesWithOffset2", func(){
    let mem = Memory.VecMemory();
    let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, BytesConverter.byteArrayConverter(5), BytesConverter.byteArrayConverter(5));

    ignore btree.insert([0, 1], []);
    ignore btree.insert([0, 2], []);
    ignore btree.insert([0, 3], []);
    ignore btree.insert([0, 4], []);
    ignore btree.insert([1, 2], []);
    ignore btree.insert([1, 4], []);
    ignore btree.insert([1, 6], []);
    ignore btree.insert([1, 8], []);
    ignore btree.insert([1, 10], []);
    ignore btree.insert([2, 1], []);
    ignore btree.insert([2, 2], []);
    ignore btree.insert([2, 3], []);
    ignore btree.insert([2, 4], []);
    ignore btree.insert([2, 5], []);
    ignore btree.insert([2, 6], []);
    ignore btree.insert([2, 7], []);
    ignore btree.insert([2, 8], []);
    ignore btree.insert([2, 9], []);

    // The result should look like this:
    //                     [(1, 4), (2, 3)]
    //                     /    |     \
    // [(0, 1), (0, 2), (0, 3), (0, 4), (1, 2)]     |    [(2, 4), (2, 5), (2, 6), (2, 7), (2, 8), (2, 9)]
    //                        |
    //               [(1, 6), (1, 8), (1, 10), (2, 1), (2, 2)]
    let root = btree.loadNode(btree.getRootAddr());
    Test.equalsNodeType(root.getNodeType(), #Internal);
    Test.equalsEntries(
      root.getEntries().toArray(),
      [
        (Blob.fromArray([1, 4]), Blob.fromArray([])),
        (Blob.fromArray([2, 3]), Blob.fromArray([])),
      ]
    );
    Test.equalsNat(root.getChildren().size(), 3);

    let child_0 = btree.loadNode(root.getChildren().get(0));
    Test.equalsNodeType(child_0.getNodeType(), #Leaf);
    Test.equalsEntries(
      child_0.getEntries().toArray(),
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
      child_1.getEntries().toArray(),
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
      child_2.getEntries().toArray(),
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
      toEntryArray(Iter.toArray(btree.range([1], ?([4])))),
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
      toEntryArray(Iter.toArray(btree.range([2], ?([2])))),
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