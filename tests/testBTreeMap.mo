import Types "../src/types";
import VecMemory "../src/memory/vecMemory";
import BTreeMap "../src/btreemap";
import Node "../src/node";
import Allocator "../src/allocator";
import Utils "../src/utils";
import Constants "../src/constants";
import Conversion "../src/conversion";

import Matchers "mo:matchers/Matchers";
import Suite "mo:matchers/Suite";
import Testable "mo:matchers/Testable";

import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Iter "mo:base/Iter";
import Int "mo:base/Int";

module {

  // For convenience: from base module
  type Iter<T> = Iter.Iter<T>;
  // For convenience: from matchers module
  let { run;test;suite; } = Suite;
  // For convenience: from types module
  type Entry = Types.Entry;
  // For convenience: from other modules
  type BTreeMap<K, V> = BTreeMap.BTreeMap<K, V>;

  // A helper method to succinctly create an entry.
  func e(x: Nat8) : Entry {
    ([x], []);
  };

  public class TestBTreeMap() = {

    let bytes_passtrough = {
      fromBytes = func(bytes: [Nat8]) : [Nat8] { bytes; };
      toBytes = func (bytes: [Nat8]) : [Nat8] { bytes; };
    };

    func initPreservesData() {
      let mem = VecMemory.VecMemory();
      var btree = BTreeMap.init<[Nat8], [Nat8]>(mem, 3, 4, bytes_passtrough, bytes_passtrough);
      assert(btree.insert([1, 2, 3], [4, 5, 6]) == #ok(null));
      assert(btree.get([1, 2, 3]) == ?([4, 5, 6]));
  
      // Reload the btree
      btree := BTreeMap.init<[Nat8], [Nat8]>(mem, 3, 4, bytes_passtrough, bytes_passtrough);
  
      // Data still exists.
      assert(btree.get([1, 2, 3]) == ?([4, 5, 6]));
    };
  
    func insertGet() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 3, 4, bytes_passtrough, bytes_passtrough);
  
      assert(btree.insert([1, 2, 3], [4, 5, 6]) == #ok(null));
      assert(btree.get([1, 2, 3]) == ?([4, 5, 6]));
    };
  
    func insertOverwritesPreviousValue() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      assert(btree.insert([1, 2, 3], [4, 5, 6]) == #ok(null));
      assert(btree.insert([1, 2, 3], [7, 8, 9]) == #ok(?([4, 5, 6])));
      assert(btree.get([1, 2, 3]) == ?([7, 8, 9]));
    };
  
    func insertGetMultiple() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      assert(btree.insert([1, 2, 3] , [4, 5, 6]) == #ok(null));
      assert(btree.insert([4, 5] , [7, 8, 9, 10]) == #ok(null));
      assert(btree.insert([], [11]) == #ok(null));
      assert(btree.get([1, 2, 3]) == ?([4, 5, 6]));
      assert(btree.get([4, 5]) == ?([7, 8, 9, 10]));
      assert(btree.get([]) == ?([11]));
    };
  
    func insertOverwriteMedianKeyInFullChildNode() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 17)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
  
      // The result should look like this:
      //        [6]
      //         /   \
      // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
  
      let root = btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [Node.makeEntry([6], [])]);
      assert(root.getChildren().size() == 2);
  
      // The right child should now be full, with the median key being "12"
      var right_child = btree.loadNode(root.getChildren().get(1));
      assert(not right_child.isFull());
      let median_index = right_child.getEntries().size() / 2;
      assert(right_child.getEntries().get(median_index).0 == [12]);
  
      // Overwrite the median key.
      assert(btree.insert([12], [1, 2, 3]) == #ok(?([])));
  
      // The key is overwritten successfully.
      assert(btree.get([12]) == ?([1, 2, 3]));
  
      // The child has not been split and is still full.
      right_child := btree.loadNode(root.getChildren().get(1));
      assert(right_child.getNodeType() == #Leaf);
      assert(not right_child.isFull());
    };
  
    func insertOverwriteKeyInFullRootNode() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
  
      // We now have a root that is full and looks like this:
      //
      // [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
      var root = btree.loadNode(btree.getRootAddr());
      assert(not root.isFull());
  
      // Overwrite an element in the root. It should NOT cause the node to be split.
      assert(btree.insert([6], [4, 5, 6]) == #ok(?([])));
  
      root := btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Leaf);
      assert(btree.get([6]) == ?([4, 5, 6]));
      assert(root.getEntries().size() == 11);
    };
  
    func allocations() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(0, Nat64.toNat(Node.getCapacity()))) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
  
      // Only need a single allocation to store up to `CAPACITY` elements.
      assert(btree.getAllocator().getNumAllocatedChunks() == 1);
  
      assert(btree.insert([255], []) == #ok(null));
  
      // The node had to be split into three nodes.
      assert(btree.getAllocator().getNumAllocatedChunks() == 3);
    };
  
    func allocations2() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
      assert(btree.getAllocator().getNumAllocatedChunks() == 0);
  
      assert(btree.insert([], []) == #ok(null));
      assert(btree.getAllocator().getNumAllocatedChunks() == 1);
  
      assert(btree.remove([]) == ?([]));
      assert(btree.getAllocator().getNumAllocatedChunks() == 0);
    };
  
    func insertSameKeyMultiple() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      assert(btree.insert([1], [2]) == #ok(null));
  
      for (i in Iter.range(2, 10)) {
        assert(btree.insert([1], [Nat8.fromNat(i) + 1]) == #ok(?([Nat8.fromNat(i)])));
      };
    };
  
    func insertSplitNode() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
  
      // Should now split a node.
      assert(btree.insert([12], []) == #ok(null));
  
      // The result should look like this:
      //        [6]
      //         /   \
      // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]
  
      for (i in Iter.range(1, 12)) {
        assert(btree.get([Nat8.fromNat(i)]) == ?([]));
      };
    };
  
    func overwriteTest() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      let num_elements = 255;
  
      // Ensure that the number of elements we insert is significantly
      // higher than `CAPACITY` so that we test interesting cases (e.g.
      // overwriting the value in an internal node).
      assert(Nat64.fromNat(num_elements) > 10 * Node.getCapacity());
  
      for (i in Iter.range(0, num_elements)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
  
      // Overwrite the values.
      for (i in Iter.range(0, num_elements)) {
        // Assert we retrieved the old value correctly.
        assert(btree.insert([Nat8.fromNat(i)], [1, 2, 3]) == #ok(?([])));
        // Assert we retrieved the new value correctly.
        assert(btree.get([Nat8.fromNat(i)]) == ?([1, 2, 3]));
      };
    };
  
    func insertSplitMultipleNodes() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
      // Should now split a node.
      assert(btree.insert([12], []) == #ok(null));
  
      // The result should look like this:
      //        [6]
      //         /   \
      // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]
  
      var root = btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [([6], [])]);
      assert(root.getChildren().size() == 2);
  
      var child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(
        child_0.getEntries().toArray() ==
        [
          ([1], []),
          ([2], []),
          ([3], []),
          ([4], []),
          ([5], [])
        ]
      );
  
      var child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(
        child_1.getEntries().toArray() ==
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
        assert(btree.get([Nat8.fromNat(i)]) == ?([]));
      };
  
      // Insert more to cause more splitting.
      assert(btree.insert([13], []) == #ok(null));
      assert(btree.insert([14], []) == #ok(null));
      assert(btree.insert([15], []) == #ok(null));
      assert(btree.insert([16], []) == #ok(null));
      assert(btree.insert([17], []) == #ok(null));
      // Should cause another split
      assert(btree.insert([18], []) == #ok(null));
  
      for (i in Iter.range(1, 18)) {
        assert(btree.get([Nat8.fromNat(i)]) == ?([]));
      };
  
      root := btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [([6], []), ([12], [])]);
      assert(root.getChildren().size() == 3);
  
      child_0 := btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(
        child_0.getEntries().toArray() ==
        [
          ([1], []),
          ([2], []),
          ([3], []),
          ([4], []),
          ([5], [])
        ]
      );
  
      child_1 := btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(
        child_1.getEntries().toArray() ==
        [
          ([7], []),
          ([8], []),
          ([9], []),
          ([10], []),
          ([11], []),
        ]
      );
  
      let child_2 = btree.loadNode(root.getChildren().get(2));
      assert(child_2.getNodeType() == #Leaf);
      assert(
        child_2.getEntries().toArray() ==
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
  
    func removeSimple() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      assert(btree.insert([1, 2, 3], [4, 5, 6]) == #ok(null));
      assert(btree.get([1, 2, 3]) == ?([4, 5, 6]));
      assert(btree.remove([1, 2, 3]) == ?([4, 5, 6]));
      assert(btree.get([1, 2, 3]) == null);
    };
  
    func removeCase2aAnd2c() {
      let mem = VecMemory.VecMemory();
      var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
      // Should now split a node.
      assert(btree.insert([0], []) == #ok(null));
  
      // The result should look like this:
      //          [6]
      //           /   \
      // [0, 1, 2, 3, 4, 5]   [7, 8, 9, 10, 11]
  
      for (i in Iter.range(0, 11)) {
        assert(btree.get([Nat8.fromNat(i)]) == ?([]));
      };
  
      // Remove node 6. Triggers case 2.a
      assert(btree.remove([6]) == ?([]));
  
      // The result should look like this:
      //        [5]
      //         /   \
      // [0, 1, 2, 3, 4]   [7, 8, 9, 10, 11]
      var root = btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [e(5)]);
      assert(root.getChildren().size() == 2);
  
      let child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(child_0.getEntries().toArray() == [e(0), e(1), e(2), e(3), e(4)]);
  
      let child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(child_1.getEntries().toArray() == [e(7), e(8), e(9), e(10), e(11)]);
  
      // There are three allocated nodes.
      assert(btree.getAllocator().getNumAllocatedChunks() == 3);
  
      // Remove node 5. Triggers case 2c
      assert(btree.remove([5]) == ?([]));
  
      // Reload the btree to verify that we saved it correctly.
      btree := BTreeMap.load(mem, bytes_passtrough, bytes_passtrough);
  
      // The result should look like this:
      // [0, 1, 2, 3, 4, 7, 8, 9, 10, 11]
      root := btree.loadNode(btree.getRootAddr());
      assert(
        root.getEntries().toArray() ==
        [e(0), e(1), e(2), e(3), e(4), e(7), e(8), e(9), e(10), e(11)]
      );
  
      // There is only one node allocated.
      assert(btree.getAllocator().getNumAllocatedChunks() == 1);
    };
  
    func removeCase2b() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
      // Should now split a node.
      assert(btree.insert([12], []) == #ok(null));
  
      // The result should look like this:
      //        [6]
      //         /   \
      // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]
  
      for (i in Iter.range(1, 12)) {
        assert(btree.get([Nat8.fromNat(i)]) == ?([]));
      };
  
      // Remove node 6. Triggers case 2.b
      assert(btree.remove([6]) == ?([]));
  
      // The result should look like this:
      //        [7]
      //         /   \
      // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
      var root = btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [e(7)]);
      assert(root.getChildren().size() == 2);
  
      let child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(child_0.getEntries().toArray() == [e(1), e(2), e(3), e(4), e(5)]);
  
      let child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(child_1.getEntries().toArray() == [e(8), e(9), e(10), e(11), e(12)]);
  
      // Remove node 7. Triggers case 2.c
      assert(btree.remove([7]) == ?([]));
      // The result should look like this:
      //
      // [1, 2, 3, 4, 5, 8, 9, 10, 11, 12]
      root := btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Leaf);
      assert(
        root.getEntries().toArray() ==
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
  
    func removeCase3aRight() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
  
      // Should now split a node.
      assert(btree.insert([12], []) == #ok(null));
  
      // The result should look like this:
      //        [6]
      //         /   \
      // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]
  
      // Remove node 3. Triggers case 3.a
      assert(btree.remove([3]) == ?([]));
  
      // The result should look like this:
      //        [7]
      //         /   \
      // [1, 2, 4, 5, 6]   [8, 9, 10, 11, 12]
      let root = btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [([7], [])]);
      assert(root.getChildren().size() == 2);
  
      let child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(child_0.getEntries().toArray() == [e(1), e(2), e(4), e(5), e(6)]);
  
      let child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(child_1.getEntries().toArray() == [e(8), e(9), e(10), e(11), e(12)]);
  
      // There are three allocated nodes.
      assert(btree.getAllocator().getNumAllocatedChunks() == 3);
    };
  
    func removeCase3aLeft() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
      // Should now split a node.
      assert(btree.insert([0], []) == #ok(null));
  
      // The result should look like this:
      //           [6]
      //          /   \
      // [0, 1, 2, 3, 4, 5]   [7, 8, 9, 10, 11]
  
      // Remove node 8. Triggers case 3.a left
      assert(btree.remove([8]) == ?([]));
  
      // The result should look like this:
      //        [5]
      //         /   \
      // [0, 1, 2, 3, 4]   [6, 7, 9, 10, 11]
      let root = btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [([5], [])]);
      assert(root.getChildren().size() == 2);
  
      let child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(child_0.getEntries().toArray() == [e(0), e(1), e(2), e(3), e(4)]);
  
      let child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(child_1.getEntries().toArray() == [e(6), e(7), e(9), e(10), e(11)]);
  
      // There are three allocated nodes.
      assert(btree.getAllocator().getNumAllocatedChunks() == 3);
    };
  
    func removeCase3bMergeIntoRight() {
      let mem = VecMemory.VecMemory();
      var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
      // Should now split a node.
      assert(btree.insert([12], []) == #ok(null));
  
      // The result should look like this:
      //        [6]
      //         /   \
      // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]
  
      for (i in Iter.range(1, 12)) {
        assert(btree.get([Nat8.fromNat(i)]) == ?([]));
      };
  
      // Remove node 6. Triggers case 2.b
      assert(btree.remove([6]) == ?([]));
      // The result should look like this:
      //        [7]
      //         /   \
      // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
      var root = btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [([7], [])]);
      assert(root.getChildren().size() == 2);
  
      let child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(child_0.getEntries().toArray() == [e(1), e(2), e(3), e(4), e(5)]);
  
      let child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(child_1.getEntries().toArray() == [e(8), e(9), e(10), e(11), e(12)]);
  
      // There are three allocated nodes.
      assert(btree.getAllocator().getNumAllocatedChunks() == 3);
  
      // Remove node 3. Triggers case 3.b
      assert(btree.remove([3]) == ?([]));
  
      // Reload the btree to verify that we saved it correctly.
      btree := BTreeMap.load(mem, bytes_passtrough, bytes_passtrough);
  
      // The result should look like this:
      //
      // [1, 2, 4, 5, 7, 8, 9, 10, 11, 12]
      root := btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Leaf);
      assert(
        root.getEntries().toArray() ==
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
      assert(btree.getAllocator().getNumAllocatedChunks() == 1);
    };
  
    func removeCase3bMergeIntoLeft() {
      let mem = VecMemory.VecMemory();
      var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 11)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
  
      // Should now split a node.
      assert(btree.insert([12], []) == #ok(null));
  
      // The result should look like this:
      //        [6]
      //         /   \
      // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]
  
      for (i in Iter.range(1, 12)) {
        assert(btree.get([Nat8.fromNat(i)]) == ?([]));
      };
  
      // Remove node 6. Triggers case 2.b
      assert(btree.remove([6]) == ?([]));
  
      // The result should look like this:
      //        [7]
      //         /   \
      // [1, 2, 3, 4, 5]   [8, 9, 10, 11, 12]
      var root = btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [([7], [])]);
      assert(root.getChildren().size() == 2);
  
      let child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(child_0.getEntries().toArray() == [e(1), e(2), e(3), e(4), e(5)]);
  
      let child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(child_1.getEntries().toArray() == [e(8), e(9), e(10), e(11), e(12)]);
  
      // There are three allocated nodes.
      assert(btree.getAllocator().getNumAllocatedChunks() == 3);
  
      // Remove node 10. Triggers case 3.b where we merge the right into the left.
      assert(btree.remove([10]) == ?([]));
  
      // Reload the btree to verify that we saved it correctly.
      btree := BTreeMap.load(mem, bytes_passtrough, bytes_passtrough);
  
      // The result should look like this:
      //
      // [1, 2, 3, 4, 5, 7, 8, 9, 11, 12]
      root := btree.loadNode(btree.getRootAddr());
      assert(root.getNodeType() == #Leaf);
      assert(
        root.getEntries().toArray() ==
        [e(1), e(2), e(3), e(4), e(5), e(7), e(8), e(9), e(11), e(12)]
      );
  
      // There is only one allocated node remaining.
      assert(btree.getAllocator().getNumAllocatedChunks() == 1);
    };
  
    func manyInsertions() {
      let mem = VecMemory.VecMemory();
      var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (j in Iter.range(0, 10)) {
        for (i in Iter.range(0, 255)) {
          let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
          assert(btree.insert(bytes, bytes) == #ok(null));
        };
      };
  
      for (j in Iter.range(0, 10)) {
        for (i in Iter.range(0, 255)) {
          let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
          assert(btree.get(bytes) == ?(bytes));
        };
      };
  
      btree := BTreeMap.load(mem, bytes_passtrough, bytes_passtrough);
  
      for (j in Iter.range(0, 10)) {
        for (i in Iter.range(0, 255)) {
          let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
          assert(btree.remove(bytes) == ?(bytes));
        };
      };
  
      for (j in Iter.range(0, 10)) {
        for (i in Iter.range(0, 255)) {
          let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
          assert(btree.get(bytes) == null);
        };
      };
  
      // We've deallocated everything.
      assert(btree.getAllocator().getNumAllocatedChunks() == 0);
    };
  
    func manyInsertions2() {
      let mem = VecMemory.VecMemory();
      var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (j in Iter.revRange(0, 10)) {
        for (i in Iter.revRange(0, 255)) {
          let bytes = [Nat8.fromNat(Int.abs(i)), Nat8.fromNat(Int.abs(j))];
          assert(btree.insert(bytes, bytes) == #ok(null));
        };
      };
  
      for (j in Iter.range(0, 10)) {
        for (i in Iter.range(0, 255)) {
          let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
          assert(btree.get(bytes) == ?(bytes));
        };
      };
  
      btree := BTreeMap.load(mem, bytes_passtrough, bytes_passtrough);
  
      for (j in Iter.revRange(0, 10)) {
        for (i in Iter.revRange((0, 255))) {
          let bytes = [Nat8.fromNat(Int.abs(i)), Nat8.fromNat(Int.abs(j))];
          assert(btree.remove(bytes) == ?(bytes));
        };
      };
  
      for (j in Iter.range(0, 10)) {
        for (i in Iter.range(0, 255)) {
          let bytes = [Nat8.fromNat(i), Nat8.fromNat(j)];
          assert(btree.get(bytes) == null);
        };
      };
  
      // We've deallocated everything.
      assert(btree.getAllocator().getNumAllocatedChunks() == 0);
    };
  
    func reloading() {
      let mem = VecMemory.VecMemory();
      var btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      // The btree is initially empty.
      assert(btree.getLength() == 0);
      assert(btree.isEmpty());
  
      // Add an entry into the btree.
      assert(btree.insert([1, 2, 3], [4, 5, 6])  == #ok(null));
      assert(btree.getLength() == 1);
      assert(not btree.isEmpty());
  
      // Reload the btree. The element should still be there, and `len()`
      // should still be `1`.
      btree := BTreeMap.load(mem, bytes_passtrough, bytes_passtrough);
      assert(btree.get([1, 2, 3]) == ?([4, 5, 6]));
      assert(btree.getLength() == 1);
      assert(not btree.isEmpty());
  
      // Remove an element. Length should be zero.
      btree := BTreeMap.load(mem, bytes_passtrough, bytes_passtrough);
      assert(btree.remove([1, 2, 3]) == ?([4, 5, 6]));
      assert(btree.getLength() == 0);
      assert(btree.isEmpty());
  
      // Reload. Btree should still be empty.
      btree := BTreeMap.load(mem, bytes_passtrough, bytes_passtrough);
      assert(btree.get([1, 2, 3]) == null);
      assert(btree.getLength() == 0);
      assert(btree.isEmpty());
    };
  
    func len() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(0, 1000)) {
        assert(btree.insert(Conversion.nat32ToBytes(Nat32.fromNat(i)), [])  == #ok(null));
      };
  
      assert(btree.getLength() == 1000);
      assert(not btree.isEmpty());
  
      for (i in Iter.range(0, 1000)) {
        assert(btree.remove(Conversion.nat32ToBytes(Nat32.fromNat(i))) == ?([]));
      };
  
      assert(btree.getLength() == 0);
      assert(btree.isEmpty());
    };
  
    func containsKey() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      // Insert even numbers from 0 to 1000.
      for (i in Iter.range(0, 500)) {
        assert(btree.insert(Conversion.nat32ToBytes(Nat32.fromNat(i * 2)), []) == #ok(null));
      };
  
      // Contains key should return true on all the even numbers and false on all the odd
      // numbers.
      for (i in Iter.range(0, 1000)) {
        assert(btree.containsKey(Conversion.nat32ToBytes(Nat32.fromNat(i)))  == (i % 2 == 0));
      };
    };
  
    func rangeEmpty() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      // Test prefixes that don't exist in the map.
      assert(Iter.toArray(btree.range([0], null)) == []);
      assert(Iter.toArray(btree.range([1, 2, 3, 4], null)) == []);
    };
  
    // Tests the case where the prefix is larger than all the entries in a leaf node.
    func rangeLeafPrefixGreaterThanAllEntries() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      ignore btree.insert([0], []);
  
      // Test a prefix that's larger than the value in the leaf node. Should be empty.
      assert(Iter.toArray(btree.range([1], null)) == []);
    };
  
    // Tests the case where the prefix is larger than all the entries in an internal node.
    func rangeInternalPrefixGreaterThanAllEntries() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      for (i in Iter.range(1, 12)) {
        assert(btree.insert([Nat8.fromNat(i)], []) == #ok(null));
      };
  
      // The result should look like this:
      //        [6]
      //         /   \
      // [1, 2, 3, 4, 5]   [7, 8, 9, 10, 11, 12]
  
      // Test a prefix that's larger than the value in the internal node.
      assert(
        Iter.toArray(btree.range([7], null)) ==
        [([7], [])]
      );
    };
  
    func rangeVariousPrefixes() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
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
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [([1, 2], [])]);
      assert(root.getChildren().size() == 2);
  
      // Tests a prefix that's smaller than the value in the internal node.
      assert(
        Iter.toArray(btree.range([0], null)) ==
        [
          ([0, 1], []),
          ([0, 2], []),
          ([0, 3], []),
          ([0, 4], []),
        ]
      );
  
      // Tests a prefix that crosses several nodes.
      assert(
        Iter.toArray(btree.range([1], null)) ==
        [
          ([1, 1], []),
          ([1, 2], []),
          ([1, 3], []),
          ([1, 4], []),
        ]
      );
  
      // Tests a prefix that's larger than the value in the internal node.
      assert(
        Iter.toArray(btree.range([2], null)) ==
        [
          ([2, 1], []),
          ([2, 2], []),
          ([2, 3], []),
          ([2, 4], []),
        ]
      );
    };
  
    func rangeVariousPrefixes2() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
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
      assert(root.getNodeType() == #Internal);
      assert(
        root.getEntries().toArray() ==
        [([1, 4], []), ([2, 3], [])]
      );
      assert(root.getChildren().size() == 3);
  
      let child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(
        child_0.getEntries().toArray() ==
        [
          ([0, 1], []),
          ([0, 2], []),
          ([0, 3], []),
          ([0, 4], []),
          ([1, 2], []),
        ]
      );
  
      let child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(
        child_1.getEntries().toArray() ==
        [
          ([1, 6], []),
          ([1, 8], []),
          ([1, 10], []),
          ([2, 1], []),
          ([2, 2], []),
        ]
      );
  
      let child_2 = btree.loadNode(root.getChildren().get(2));
      assert(
        child_2.getEntries().toArray() ==
        [
          ([2, 4], []),
          ([2, 5], []),
          ([2, 6], []),
          ([2, 7], []),
          ([2, 8], []),
          ([2, 9], []),
        ]
      );
  
      // Tests a prefix that doesn't exist, but is in the middle of the root node.
      assert(Iter.toArray(btree.range([1, 5], null)) == []);
  
      // Tests a prefix that crosses several nodes.
      assert(
        Iter.toArray(btree.range([1], null)) ==
        [
          ([1, 2], []),
          ([1, 4], []),
          ([1, 6], []),
          ([1, 8], []),
          ([1, 10], []),
        ]
      );
  
      // Tests a prefix that starts from a leaf node, then iterates through the root and right
      // sibling.
      assert(
        Iter.toArray(btree.range([2], null)) ==
        [
          ([2, 1], []),
          ([2, 2], []),
          ([2, 3], []),
          ([2, 4], []),
          ([2, 5], []),
          ([2, 6], []),
          ([2, 7], []),
          ([2, 8], []),
          ([2, 9], []),
        ]
      );
    };
  
    func rangeLarge() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
      // Insert 1000 elements with prefix 0 and another 1000 elements with prefix 1.
      for (prefix in Iter.range(0, 1)) {
        for (i in Iter.range(0, 1000)) {
          // The key is the prefix followed by the integer's encoding.
          // The encoding is big-endian so that the byte representation of the
          // integers are sorted.
          // @todo: here it is supposed to be in big endian!
          let key = Utils.append([Nat8.fromNat(prefix)], Conversion.nat32ToBytes(Nat32.fromNat(i)));
          assert(btree.insert(key, []) == #ok(null));
        };
      };
  
      // Getting the range with a prefix should return all 1000 elements with that prefix.
      for (prefix in Iter.range(0, 1)) {
        var i : Nat32 = 0;
        for ((key, _) in btree.range([Nat8.fromNat(prefix)], null)) {
          // @todo: here it is supposed to be in big endian!
          assert(key == Utils.append([Nat8.fromNat(prefix)], Conversion.nat32ToBytes(i)));
          i += 1;
        };
        assert(i == 1000);
      };
    };
  
    func rangeVariousPrefixesWithOffset() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
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
      assert(root.getNodeType() == #Internal);
      assert(root.getEntries().toArray() == [([1, 2], [])]);
      assert(root.getChildren().size() == 2);
  
      // Tests a offset that's smaller than the value in the internal node.
      assert(
        Iter.toArray(btree.range([0], ?([0]))) ==
        [
          ([0, 1], []),
          ([0, 2], []),
          ([0, 3], []),
          ([0, 4], []),
        ]
      );
  
      // Tests a offset that has a value somewhere in the range of values of an internal node.
      assert(
        Iter.toArray(btree.range([1], ?([3]))) ==
        [([1, 3], []), ([1, 4], []),]
      );
  
      // Tests a offset that's larger than the value in the internal node.
      assert(
        Iter.toArray(btree.range([2], ?([5]))) ==
        [],
      );
    };
  
    func rangeVariousPrefixesWithOffset2() {
      let mem = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(mem, 5, 5, bytes_passtrough, bytes_passtrough);
  
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
      assert(root.getNodeType() == #Internal);
      assert(
        root.getEntries().toArray() ==
        [([1, 4], []), ([2, 3], [])]
      );
      assert(root.getChildren().size() == 3);
  
      let child_0 = btree.loadNode(root.getChildren().get(0));
      assert(child_0.getNodeType() == #Leaf);
      assert(
        child_0.getEntries().toArray() ==
        [
          ([0, 1], []),
          ([0, 2], []),
          ([0, 3], []),
          ([0, 4], []),
          ([1, 2], []),
        ]
      );
  
      let child_1 = btree.loadNode(root.getChildren().get(1));
      assert(child_1.getNodeType() == #Leaf);
      assert(
        child_1.getEntries().toArray() ==
        [
          ([1, 6], []),
          ([1, 8], []),
          ([1, 10], []),
          ([2, 1], []),
          ([2, 2], []),
        ]
      );
  
      let child_2 = btree.loadNode(root.getChildren().get(2));
      assert(
        child_2.getEntries().toArray() ==
        [
          ([2, 4], []),
          ([2, 5], []),
          ([2, 6], []),
          ([2, 7], []),
          ([2, 8], []),
          ([2, 9], []),
        ]
      );
  
      // Tests a offset that crosses several nodes.
      assert(
        Iter.toArray(btree.range([1], ?([4]))) ==
        [
          ([1, 4], []),
          ([1, 6], []),
          ([1, 8], []),
          ([1, 10], []),
        ]
      );
  
      // Tests a offset that starts from a leaf node, then iterates through the root and right
      // sibling.
      assert(
        Iter.toArray(btree.range([2], ?([2]))) ==
        [
          ([2, 2], []),
          ([2, 3], []),
          ([2, 4], []),
          ([2, 5], []),
          ([2, 6], []),
          ([2, 7], []),
          ([2, 8], []),
          ([2, 9], []),
        ]
      );
    };

    public func getSuite() : Suite.Suite {
      suite("Test btreemap module", []);
    };
  
  };
};