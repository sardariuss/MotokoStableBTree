import Constants "../constants";

import StableMemory "mo:base/ExperimentalStableMemory";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";

module {

  public let STABLE_MEMORY = {
    size = func() : Nat64 { 
      StableMemory.size(); 
    };
    store = func(address: Nat64, bytes: [Nat8]) {
      // Ensure there is enough space to store the bytes
      ensure(address + Nat64.fromNat(bytes.size()));
      StableMemory.storeBlob(address, Blob.fromArray(bytes));
    };
    load = func(address: Nat64, size: Nat) : [Nat8] {
      Blob.toArray(StableMemory.loadBlob(address, size));
    };
  };
  
  func ensure(offset : Nat64) {
    let pages = (offset + Constants.WASM_PAGE_SIZE) >> 16;
    if (pages > StableMemory.size()) {
      let oldsize = StableMemory.grow(pages - StableMemory.size());
      assert (oldsize != 0xFFFF_FFFF_FFFF_FFFF);
    };
  };

};