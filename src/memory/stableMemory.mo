import Types "../types";
import Constants "../constants";

import StableMemory "mo:base/ExperimentalStableMemory";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";

module {

  // For convenience: from types module
  type Memory<T> = Types.Memory<T>;

  public let STABLE_MEMORY : Memory<()> = {
    size = func(memory: Memory<()>) : Nat64 { 
      StableMemory.size(); 
    };
    store = func(memory: Memory<()>, address: Nat64, bytes: [Nat8]) : Memory<()> {
      // Ensure there is enough space to store the bytes
      ensure(address + Nat64.fromNat(bytes.size()));
      StableMemory.storeBlob(address, Blob.fromArray(bytes));
      memory;
    };
    load = func(memory: Memory<()>, address: Nat64, size: Nat) : [Nat8] {
      Blob.toArray(StableMemory.loadBlob(address, size));
    };
    t = ();
  };
  
  func ensure(offset : Nat64) {
    let pages = (offset + Constants.WASM_PAGE_SIZE) >> 16;
    if (pages > StableMemory.size()) {
      let oldsize = StableMemory.grow(pages - StableMemory.size());
      assert (oldsize != 0xFFFF_FFFF_FFFF_FFFF);
    };
  };

};