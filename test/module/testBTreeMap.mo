import Types "../../src/types";
import BTreeMap "../../src/btreemap";
import Node "../../src/node";
import Utils "../../src/utils";
import Conversion "../../src/conversion";
import TestableItems "testableItems";

import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Order "mo:base/Order";
import Buffer "mo:base/Buffer";

module {

  // For convenience: from base module
  type Iter<T> = Iter.Iter<T>;
  type Order = Order.Order;
  type Buffer<T> = Buffer.Buffer<T>;
  // For convenience: from other modules
  type BTreeMap<K, V> = BTreeMap.BTreeMap<K, V>;
  type TestBuffer = TestableItems.TestBuffer;

  // For convenience: from types module
  type BytesEntry = Types.Entry<[Nat8], [Nat8]>;

  /// Compare two bytes
  func bytesOrder(a: [Nat8], b: [Nat8]) : Order {
    Utils.lexicographicallyCompare(a, b, Nat8.compare);
  };

  /// A helper method to succinctly create an entry.
  func e(x: Nat8) : BytesEntry {
    ([x], []);
  };

  func insertGet(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    test.equalsOptBytes(btree.insert([1, 2, 3], [4, 5, 6]), null);
    test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));
  };

  func insertOverwritesPreviousValue(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    test.equalsOptBytes(btree.insert([1, 2, 3], [4, 5, 6]), null);
    test.equalsOptBytes(btree.insert([1, 2, 3], [7, 8, 9]), ?([4, 5, 6]));
    test.equalsOptBytes(btree.get([1, 2, 3]), ?([7, 8, 9]));
  };

  func insertGetMultiple(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    test.equalsOptBytes(btree.insert([1, 2, 3] , [4, 5, 6]), null);
    test.equalsOptBytes(btree.insert([4, 5] , [7, 8, 9, 10]), null);
    test.equalsOptBytes(btree.insert([], [11]), null);
    test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));
    test.equalsOptBytes(btree.get([4, 5]), ?([7, 8, 9, 10]));
    test.equalsOptBytes(btree.get([]), ?([11]));
  };

  func insertOverwriteMedianKeyInFullChildNode(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 17)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]

    let root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [([6], [])]);
    test.equalsNat(root.getChildren().size(), 2);

    // The right child should now be full, with the median key being "12"
    var right_child = root.getChildren().get(1);
    test.equalsBool(right_child.isFull(), true);
    let median_index = right_child.getEntries().size() / 2;
    test.equalsBytes(right_child.getEntries().get(median_index).0, [12]);

    // Overwrite the median key.
    test.equalsOptBytes(btree.insert([12], [1, 2, 3]), ?([]));

    // The key is overwritten successfully.
    test.equalsOptBytes(btree.get([12]), ?([1, 2, 3]));

    // The child has not been split and is still full.
    right_child := root.getChildren().get(1);
    test.equalsNodeType(right_child.getNodeType(), #Leaf);
    test.equalsBool(right_child.isFull(), true);
  };

  func insertOverwriteKeyInFullRootNode(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };

    // We now have a root that is full and looks like this:
    //
    // [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    var root = btree.getRootNode();
    test.equalsBool(root.isFull(), true);

    // Overwrite an element in the root. It should NOT cause the node to be split.
    test.equalsOptBytes(btree.insert([6], [4, 5, 6]), ?([]));

    root := btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Leaf);
    test.equalsOptBytes(btree.get([6]), ?([4, 5, 6]));
    test.equalsNat(root.getEntries().size(), 11);
  };

  func insertSameKeyMultiple(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    test.equalsOptBytes(btree.insert([1], [2]), null);

    for (i in Iter.range(2, 9)) {
      test.equalsOptBytes(btree.insert([1], [Nat8.fromNat(i) + 1]), ?([Nat8.fromNat(i)]));
    };
  };

  func insertSplitNode(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };

    // Should now split a node.
    test.equalsOptBytes(btree.insert([12], []), null);

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };
  };

  func overwriteTest(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    let num_elements = 255;

    // Ensure that the number of elements we insert is significantly
    // higher than `CAPACITY` so that we test interesting cases (e.g.
    // overwriting the value in an internal node).
    assert(Nat64.fromNat(num_elements) > 10 * Node.getCapacity());

    for (i in Iter.range(0, num_elements - 1)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };

    // Overwrite the values.
    for (i in Iter.range(0, num_elements - 1)) {
      // Assert we retrieved the old value correctly.
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], [1, 2, 3]), ?([]));
      // Assert we retrieved the new value correctly.
      test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([1, 2, 3]));
    };
  };

  func insertSplitMultipleNodes(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };
    // Should now split a node.
    test.equalsOptBytes(btree.insert([12], []), null);

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    var root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [([6], [])]);
    test.equalsNat(root.getChildren().size(), 2);

    var child_0 = root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsBytesEntries(
      child_0.getEntries().toArray(),
      [
        ([1], []),
        ([2], []),
        ([3], []),
        ([4], []),
        ([5], [])
      ]
    );

    var child_1 = root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsBytesEntries(
      child_1.getEntries().toArray(),
      [
        ([7], []),
        ([8], []),
        ([9], []),
        ([10], []),
        ([11], []),
        ([12], [])
      ]
    );

    for (i in Iter.range(1, 12)) {
      test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Insert more to cause more splitting.
    test.equalsOptBytes(btree.insert([13], []), null);
    test.equalsOptBytes(btree.insert([14], []), null);
    test.equalsOptBytes(btree.insert([15], []), null);
    test.equalsOptBytes(btree.insert([16], []), null);
    test.equalsOptBytes(btree.insert([17], []), null);
    // Should cause another split
    test.equalsOptBytes(btree.insert([18], []), null);

    for (i in Iter.range(1, 18)) {
      test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    root := btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [([6], []), ([12], [])]);
    test.equalsNat(root.getChildren().size(), 3);

    child_0 := root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsBytesEntries(
      child_0.getEntries().toArray(),
      [
        ([1], []),
        ([2], []),
        ([3], []),
        ([4], []),
        ([5], [])
      ]
    );

    child_1 := root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsBytesEntries(
      child_1.getEntries().toArray(),
      [
        ([7], []),
        ([8], []),
        ([9], []),
        ([10], []),
        ([11], []),
      ]
    );

    let child_2 = root.getChildren().get(2);
    test.equalsNodeType(child_2.getNodeType(), #Leaf);
    test.equalsBytesEntries(
      child_2.getEntries().toArray(),
      [
        ([13], []),
        ([14], []),
        ([15], []),
        ([16], []),
        ([17], []),
        ([18], []),
      ]
    );
  };

  func removeSimple(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    test.equalsOptBytes(btree.insert([1, 2, 3], [4, 5, 6]), null);
    test.equalsOptBytes(btree.get([1, 2, 3]), ?([4, 5, 6]));
    test.equalsOptBytes(btree.remove([1, 2, 3]), ?([4, 5, 6]));
    test.equalsOptBytes(btree.get([1, 2, 3]), null);
  };

  func removeCase2aAnd2c(test: TestBuffer) {
    var btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };
    // Should now split a node.
    test.equalsOptBytes(btree.insert([0], []), null);

    // The result should look like this:
    //          [6]
    //           /   \
    // [0, 1, 2, 3, 4, 5]   [7, 8, 9, 10, 11]

    for (i in Iter.range(0, 11)) {
      test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Remove node 6. Triggers case 2.a
    test.equalsOptBytes(btree.remove([6]), ?([]));

    // The result should look like this:
    //        [5]
    //         /   \
    // [0, 1, 2, 3, 4]   [7, 8, 9, 10, 11]
    var root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [e(5)]);
    test.equalsNat(root.getChildren().size(), 2);

    let child_0 = root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_0.getEntries().toArray(), [e(0), e(1), e(2), e(3), e(4)]);

    let child_1 = root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_1.getEntries().toArray(), [e(7), e(8), e(9), e(10), e(11)]);

    // Remove node 5. Triggers case 2c
    test.equalsOptBytes(btree.remove([5]), ?([]));

    // The result should look like this:
    // [0, 1, 2, 3, 4, 7, 8, 9, 10, 11]
    root := btree.getRootNode();
    test.equalsBytesEntries(
      root.getEntries().toArray(),
      [e(0), e(1), e(2), e(3), e(4), e(7), e(8), e(9), e(10), e(11)]
    );

  };

  func removeCase2b(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };
    // Should now split a node.
    test.equalsOptBytes(btree.insert([12], []), null);

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    test.equalsOptBytes(btree.remove([6]), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [e(7)]);
    test.equalsNat(root.getChildren().size(), 2);

    let child_0 = root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_0.getEntries().toArray(), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_1.getEntries().toArray(), [e(8), e(9), e(10), e(11), e(12)]);

    // Remove node 7. Triggers case 2.c
    test.equalsOptBytes(btree.remove([7]), ?([]));
    // The result should look like this:
    //
    // [1, 2, 3, 4, 5, 8, 9, 10, 11, 12]
    root := btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Leaf);
    test.equalsBytesEntries(
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
  };

  func removeCase3aRight(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };

    // Should now split a node.
    test.equalsOptBytes(btree.insert([12], []), null);

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    // Remove node 3. Triggers case 3.a
    test.equalsOptBytes(btree.remove([3]), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 4, 5, 6]   [8, 9, 10, 11, 12]
    let root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [([7], [])]);
    test.equalsNat(root.getChildren().size(), 2);

    let child_0 = root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_0.getEntries().toArray(), [e(1), e(2), e(4), e(5), e(6)]);

    let child_1 = root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_1.getEntries().toArray(), [e(8), e(9), e(10), e(11), e(12)]);
  };

  func removeCase3aLeft(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };
    // Should now split a node.
    test.equalsOptBytes(btree.insert([0], []), null);

    // The result should look like this:
    //           [6]
    //          /   \
    // [0, 1, 2, 3, 4, 5]   [7, 8, 9, 10, 11]

    // Remove node 8. Triggers case 3.a left
    test.equalsOptBytes(btree.remove([8]), ?([]));

    // The result should look like this:
    //        [5]
    //         /   \
    // [0, 1, 2, 3, 4]   [6, 7, 9, 10, 11]
    let root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [([5], [])]);
    test.equalsNat(root.getChildren().size(), 2);

    let child_0 = root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_0.getEntries().toArray(), [e(0), e(1), e(2), e(3), e(4)]);

    let child_1 = root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_1.getEntries().toArray(), [e(6), e(7), e(9), e(10), e(11)]);
  };

  func removeCase3bMergeIntoRight(test: TestBuffer) {
    var btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };
    // Should now split a node.
    test.equalsOptBytes(btree.insert([12], []), null);

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    test.equalsOptBytes(btree.remove([6]), ?([]));
    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [([7], [])]);
    test.equalsNat(root.getChildren().size(), 2);

    let child_0 = root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_0.getEntries().toArray(), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_1.getEntries().toArray(), [e(8), e(9), e(10), e(11), e(12)]);

    // Remove node 3. Triggers case 3.b
    test.equalsOptBytes(btree.remove([3]), ?([]));

    // The result should look like this:
    //
    // [1, 2, 4, 5, 7, 8, 9, 10, 11, 12]
    root := btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Leaf);
    test.equalsBytesEntries(
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
  };

  func removeCase3bMergeIntoLeft(test: TestBuffer) {
    var btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(1, 11)) {
      test.equalsOptBytes(btree.insert([Nat8.fromNat(i)], []), null);
    };

    // Should now split a node.
    test.equalsOptBytes(btree.insert([12], []), null);

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    for (i in Iter.range(1, 12)) {
      test.equalsOptBytes(btree.get([Nat8.fromNat(i)]), ?([]));
    };

    // Remove node 6. Triggers case 2.b
    test.equalsOptBytes(btree.remove([6]), ?([]));

    // The result should look like this:
    //        [7]
    //         /   \
    // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
    var root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsBytesEntries(root.getEntries().toArray(), [([7], [])]);
    test.equalsNat(root.getChildren().size(), 2);

    let child_0 = root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_0.getEntries().toArray(), [e(1), e(2), e(3), e(4), e(5)]);

    let child_1 = root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsBytesEntries(child_1.getEntries().toArray(), [e(8), e(9), e(10), e(11), e(12)]);

    // Remove node 10. Triggers case 3.b where we merge the right into the left.
    test.equalsOptBytes(btree.remove([10]), ?([]));

    // The result should look like this:
    //
    // [1, 2, 3, 4, 5, 7, 8, 9, 11, 12]
    root := btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Leaf);
    test.equalsBytesEntries(
      root.getEntries().toArray(),
      [e(1), e(2), e(3), e(4), e(5), e(7), e(8), e(9), e(11), e(12)]
    );
  };

  func manyInsertions(test: TestBuffer) {
    var btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        test.equalsOptBytes(btree.insert(bytes, bytes), null);
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        test.equalsOptBytes(btree.get(bytes), ?(bytes));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        test.equalsOptBytes(btree.remove(bytes), ?(bytes));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        test.equalsOptBytes(btree.get(bytes), null);
      };
    };
  };

  func manyInsertions2(test: TestBuffer) {
    var btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (j in Iter.revRange(10, 0)) {
      for (i in Iter.revRange(255, 0)) {
        let bytes = [Nat8.fromNat(Int.abs(i)), Nat8.fromNat(Int.abs(j))];
        test.equalsOptBytes(btree.insert(bytes, bytes), null);
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        test.equalsOptBytes(btree.get(bytes), ?(bytes));
      };
    };

    for (j in Iter.revRange(10, 0)) {
      for (i in Iter.revRange((255, 0))) {
        let bytes = [Nat8.fromNat(Int.abs(i)), Nat8.fromNat(Int.abs(j))];
        test.equalsOptBytes(btree.remove(bytes), ?(bytes));
      };
    };

    for (j in Iter.range(0, 10)) {
      for (i in Iter.range(0, 255)) {
        let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
        test.equalsOptBytes(btree.get(bytes), null);
      };
    };
  };

  func len(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    for (i in Iter.range(0, 999)) {
      test.equalsOptBytes(btree.insert(Conversion.nat32ToBytes(Nat32.fromNat(i)), []) , null);
    };

    test.equalsNat64(btree.getLength(), 1000);
    test.equalsBool(btree.isEmpty(), false);

    for (i in Iter.range(0, 999)) {
      test.equalsOptBytes(btree.remove(Conversion.nat32ToBytes(Nat32.fromNat(i))), ?([]));
    };

    test.equalsNat64(btree.getLength(), 0);
    test.equalsBool(btree.isEmpty(), true);
  };

  func containsKey(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<[Nat8], [Nat8]>(bytesOrder);

    // Insert even numbers from 0 to 1000.
    for (i in Iter.range(0, 499)) {
      test.equalsOptBytes(btree.insert(Conversion.nat32ToBytes(Nat32.fromNat(i * 2)), []), null);
    };

    // Contains key should return true on all the even numbers and false on all the odd
    // numbers.
    for (i in Iter.range(0, 499)) {
      test.equalsBool(btree.containsKey(Conversion.nat32ToBytes(Nat32.fromNat(i))), (i % 2 == 0));
    };
  };

  func rangeEmpty(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<Nat, Nat>(Nat.compare);

    // Test entries are not in the map.
    test.equalsNatEntries(Iter.toArray(btree.range(0, 10)), []);
    test.equalsNatEntries(Iter.toArray(btree.range(20, 40)), []);
  };

  // Tests the case where the lower bound is greater than all the entries in a leaf node.
  // Tests the case where the upper bound is lower than all the entries in a leaf node.
  func rangeBoundsOutsideOfAllEntries(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<Nat, Nat>(Nat.compare);

    ignore btree.insert(5, 5);

    // Test a lower bound that's larger than the value in the leaf node. Should be empty.
    test.equalsNatEntries(Iter.toArray(btree.range(6, 10)), []);

    // Test an upper bound that's lower than the value in the leaf node. Should be empty.
    test.equalsNatEntries(Iter.toArray(btree.range(1, 4)), []);
  };

  // Tests the case where the lower bound is greater than all the entries in an internal node.
  // Tests the case where the upper bound is lower than all the entries in an internal node.
  func rangeInternalOutsideOfAllEntries(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<Nat, Nat>(Nat.compare);

    for (i in Iter.range(1, 12)) {
      test.equalsOptNat(btree.insert(i, i), null);
    };

    // The result should look like this:
    //        [6]
    //         /   \
    // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]

    // Test a lower bound that's greater than the value in the internal node.
    test.equalsNatEntries(
      Iter.toArray(btree.range(7, 100)),
      [(7, 7), (8, 8), (9, 9), (10, 10), (11, 11), (12, 12)]
    );
    // Test an upper bound that's lower than the value in the internal node.
    test.equalsNatEntries(
      Iter.toArray(btree.range(0, 5)),
      [(1, 1), (2, 2), (3, 3), (4, 4), (5, 5)]
    );
  };

  func rangeVariousLowerBounds(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<Nat, Nat>(Nat.compare);

    ignore btree.insert( 1,  1);
    ignore btree.insert( 2,  2);
    ignore btree.insert( 3,  3);
    ignore btree.insert( 4,  4);
    ignore btree.insert( 5,  5);
    ignore btree.insert( 6,  6);
    ignore btree.insert( 7,  7);
    ignore btree.insert( 8,  8);
    ignore btree.insert( 9,  9);
    ignore btree.insert(10, 10);
    ignore btree.insert(11, 11);
    ignore btree.insert(12, 12);

    // The result should look like this:
    //                     [( 6)]
    //                     /   \
    // [( 1)( 2)( 3)( 4)( 5)]     [( 7)( 8)( 9)(10)(11)(12)]

    let root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsNatEntries(root.getEntries().toArray(), [(6, 6)]);
    test.equalsNat(root.getChildren().size(), 2);

    // Tests a lower bound that's smaller than the value in the internal node.
    test.equalsNatEntries(
      Iter.toArray(btree.range(4, 1000)),
      [
        (4, 4),
        (5, 5),
        (6, 6),
        (7, 7),
        (8, 8),
        (9, 9),
        (10, 10),
        (11, 11),
        (12, 12),
      ]
    );

    // Tests a lower bound that is an entry in the internal node.
    test.equalsNatEntries(
      Iter.toArray(btree.range(6, 1000)),
      [
        (6, 6),
        (7, 7),
        (8, 8),
        (9, 9),
        (10, 10),
        (11, 11),
        (12, 12),
      ]
    );

    // Tests a lower bound that's greater than the value in the internal node.
    test.equalsNatEntries(
      Iter.toArray(btree.range(10, 1000)),
      [
        (10, 10),
        (11, 11),
        (12, 12),
      ]
    );
  };

  func rangeVariousUpperBounds(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<Nat, Nat>(Nat.compare);

    ignore btree.insert( 1,  1);
    ignore btree.insert( 2,  2);
    ignore btree.insert( 3,  3);
    ignore btree.insert( 4,  4);
    ignore btree.insert( 5,  5);
    ignore btree.insert( 6,  6);
    ignore btree.insert( 7,  7);
    ignore btree.insert( 8,  8);
    ignore btree.insert( 9,  9);
    ignore btree.insert(10, 10);
    ignore btree.insert(11, 11);
    ignore btree.insert(12, 12);

    // The result should look like this:
    //                     [( 6)]
    //                     /   \
    // [( 1)( 2)( 3)( 4)( 5)]     [( 7)( 8)( 9)(10)(11)(12)]

    let root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsNatEntries(root.getEntries().toArray(), [(6, 6)]);
    test.equalsNat(root.getChildren().size(), 2);

    // Tests an upper bound that's smaller than the value in the internal node.
    test.equalsNatEntries(
      Iter.toArray(btree.range(0, 4)),
      [
        (1, 1),
        (2, 2),
        (3, 3),
        (4, 4),
      ]
    );

    // Tests an upper bound that is an entry in the internal node.
    test.equalsNatEntries(
      Iter.toArray(btree.range(0, 6)),
      [
        (1, 1),
        (2, 2),
        (3, 3),
        (4, 4),
        (5, 5),
        (6, 6),
      ]
    );

    // Tests a upper bound that's greater than the value in the internal node.
    test.equalsNatEntries(
      Iter.toArray(btree.range(0, 10)),
      [
        (1, 1),
        (2, 2),
        (3, 3),
        (4, 4),
        (5, 5),
        (6, 6),
        (7, 7),
        (8, 8),
        (9, 9),
        (10, 10),
      ]
    );
  };

  func rangeVariousBounds(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<Nat, Nat>(Nat.compare);

    ignore btree.insert( 1,  1);
    ignore btree.insert( 2,  2);
    ignore btree.insert( 3,  3);
    ignore btree.insert( 4,  4);
    ignore btree.insert( 5,  5);
    ignore btree.insert( 6,  6);
    ignore btree.insert( 7,  7);
    ignore btree.insert( 8,  8);
    ignore btree.insert( 9,  9);
    ignore btree.insert(21, 21);
    ignore btree.insert(22, 22);
    ignore btree.insert(23, 23);
    ignore btree.insert(24, 24);
    ignore btree.insert(25, 25);
    ignore btree.insert(26, 26);
    ignore btree.insert(27, 27);
    ignore btree.insert(28, 28);
    ignore btree.insert(29, 29);

    // The result should look like this:
    //                      [( 6)(23)]
    //                     /    |     \
    // [( 1)( 2)( 3)( 4)( 5)]   |    [(24)(25)(26)(27)(28)(29)]
    //                          |
    //               [( 7)( 8)( 9)(21)(22)]
    let root = btree.getRootNode();
    test.equalsNodeType(root.getNodeType(), #Internal);
    test.equalsNatEntries(
      root.getEntries().toArray(),
      [(6, 6), (23, 23)]
    );
    test.equalsNat(root.getChildren().size(), 3);

    let child_0 = root.getChildren().get(0);
    test.equalsNodeType(child_0.getNodeType(), #Leaf);
    test.equalsNatEntries(
      child_0.getEntries().toArray(),
      [
        (1, 1),
        (2, 2),
        (3, 3),
        (4, 4),
        (5, 5),
      ]
    );

    let child_1 = root.getChildren().get(1);
    test.equalsNodeType(child_1.getNodeType(), #Leaf);
    test.equalsNatEntries(
      child_1.getEntries().toArray(),
      [
        ( 7,  7),
        ( 8,  8),
        ( 9,  9),
        (21, 21),
        (22, 22),
      ]
    );

    let child_2 = root.getChildren().get(2);
    test.equalsNatEntries(
      child_2.getEntries().toArray(),
      [
        (24, 24),
        (25, 25),
        (26, 26),
        (27, 27),
        (28, 28),
        (29, 29),
      ]
    );

    // Tests bounds that don't cross any entry, but is in the middle of the root node.
    test.equalsNatEntries(Iter.toArray(btree.range(10, 20)), []);

    // Tests bounds that crosses several nodes
    test.equalsNatEntries(
      Iter.toArray(btree.range(5, 10)),
      [
        (5, 5),
        (6, 6),
        (7, 7),
        (8, 8),
        (9, 9),
      ]
    );

    // Tests bounds that starts from a leaf node, then iterates through the root and right
    // sibling.
    test.equalsNatEntries(
      Iter.toArray(btree.range(22, 26)),
      [
        (22, 22),
        (23, 23),
        (24, 24),
        (25, 25),
        (26, 26),
      ]
    );
  };

  func rangeLarge(test: TestBuffer) {
    let btree = BTreeMap.BTreeMap<Nat, Nat>(Nat.compare);

    // Insert 1000 elements
    for (i in Iter.range(0, 999)) {
      test.equalsOptNat(btree.insert(i, i), null);
    };

    // Iterate on elements with a window of size 100, and verify that the range of elements
    // returned is correct.
    for (i in Iter.range(0, 899)) {
      let lower = i;
      let upper = lower + 100;

      let expected_entries = Buffer.Buffer<(Nat, Nat)>(100);
      for (inner in Iter.range(lower, upper)){
        expected_entries.add((inner, inner));
      };

      test.equalsNatEntries(Iter.toArray(btree.range(lower, upper)), expected_entries.toArray());
    };
  };

  public func run() {
    let test = TestableItems.TestBuffer();

    insertGet(test);
    insertOverwritesPreviousValue(test);
    insertGetMultiple(test);
    insertOverwriteMedianKeyInFullChildNode(test);
    insertOverwriteKeyInFullRootNode(test);
    insertSameKeyMultiple(test);
    insertSplitNode(test);
    overwriteTest(test);
    insertSplitMultipleNodes(test);
    removeSimple(test);
    removeCase2aAnd2c(test);
    removeCase2b(test);
    removeCase3aRight(test);
    removeCase3aLeft(test);
    removeCase3bMergeIntoRight(test);
    removeCase3bMergeIntoLeft(test);
    manyInsertions(test);
    manyInsertions2(test);
    len(test);
    containsKey(test);
    rangeEmpty(test);
    rangeBoundsOutsideOfAllEntries(test);
    rangeInternalOutsideOfAllEntries(test);
    rangeVariousLowerBounds(test);
    rangeVariousUpperBounds(test);
    rangeVariousBounds(test);
    rangeLarge(test);

    test.run("Test btreemap module");
  };

};