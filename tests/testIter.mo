import VecMemory "../src/memory/vecMemory";
import BTreeMap "../src/btreemap";
import Node "../src/node";

import Suite "mo:matchers/Suite";

import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";

module {

  // For convenience: from matchers module
  let { run;test;suite; } = Suite;

  public class TestIter() = {

    func iterateLeaf() {
      let bytes_passtrough = {
        fromBytes = func(bytes: [Nat8]) : [Nat8] { bytes; };
        toBytes = func (bytes: [Nat8]) : [Nat8] { bytes; };
      };

      // Iterate on leaf
      let memory = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(memory, 1, 1, bytes_passtrough, bytes_passtrough);

      for (i in Iter.range(0, Nat64.toNat(Node.getCapacity() - 1))){
        ignore btree.insert([Nat8.fromNat(i)], [Nat8.fromNat(i + 1)]);
      };

      var i : Nat8 = 0;
      for ((key, value) in btree.iter()){
        assert(key == [i]);
        assert(value == [i + 1]);
        i += 1;
      };

      assert(Nat8.toNat(i) == Nat64.toNat(Node.getCapacity()));
    };

    func iterateChildren() {
      let bytes_passtrough = {
        fromBytes = func(bytes: [Nat8]) : [Nat8] { bytes; };
        toBytes = func (bytes: [Nat8]) : [Nat8] { bytes; };
      };

      // Iterate on leaf
      let memory = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(memory, 1, 1, bytes_passtrough, bytes_passtrough);

      // Insert the elements in reverse order.
      for (i in Iter.revRange(99, 0)){
        ignore btree.insert([Nat8.fromNat(Int.abs(i))], [Nat8.fromNat(Int.abs(i + 1))]);
      };

      // Iteration should be in ascending order.
      var i : Nat8 = 0;
      for ((key, value) in btree.iter()){
        assert(key == [i]);
        assert(value == [i + 1]);
        i += 1;
      };

      assert(i == 100);
    };

    public func getSuite() : Suite.Suite {
      
      iterateLeaf();
      iterateChildren();

      suite("Test iter module", []);
    };
  };

};