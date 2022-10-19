import Types "../src/types";
import VecMemory "../src/memory/vecMemory";
import BTreeMap "../src/btreemap";
import Utils "../src/utils";
import Node "../src/node";

import Matchers "mo:matchers/Matchers";
import Suite "mo:matchers/Suite";
import Testable "mo:matchers/Testable";

import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";

module {

  // For convenience: from base module
  // @todo
  // For convenience: from matchers module
  let { run;test;suite; } = Suite;

  public class TestIter() = {

    public func getSuite() : Suite.Suite {
      
      let tests = Buffer.Buffer<Suite.Suite>(0);

      let bytes_passtrough = {
        fromBytes = func(bytes: [Nat8]) : [Nat8] { bytes; };
        toBytes = func (bytes: [Nat8]) : [Nat8] { bytes; };
      };

      // Iterate on leaf
      let memory = VecMemory.VecMemory();
      let btree = BTreeMap.new<[Nat8], [Nat8]>(memory, 1, 1, bytes_passtrough, bytes_passtrough);

      for (i in Iter.range(0, Nat64.toNat(Node.getCapacity()))){
        ignore btree.insert([Nat8.fromNat(i)], [Nat8.fromNat(i + 1)]);
      };

      var i : Nat8 = 0;
      for ((key, value) in btree.iter()){
        assert(key == [i]);
        assert(value == [i + 1]);
        i += 1;
      };

      // Iterate on children @todo

      suite("Test iter module", tests.toArray());
    };
  };

};