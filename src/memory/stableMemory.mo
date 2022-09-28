import Types "../types";
import AlignedStruct "../alignedStruct";

import StableMemory "mo:base/ExperimentalStableMemory";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

module {

  // For convenience: from types module
  type Address = Types.Address;
  type Variant = Types.Variant;
  type AlignedStruct = Types.AlignedStruct;
  type AlignedStructDefinition = Types.AlignedStructDefinition;
  type Memory<T> = Types.Memory<T>;

  public let STABLE_MEMORY : Memory<()> = {
    size = func(memory: Memory<()>) : Nat64 { 
      StableMemory.size(); 
    };
    store = func(memory: Memory<()>, address: Nat64, struct: AlignedStruct) : Memory<()> {
      storeAlignedStruct(struct, address);
      memory;
    };
    load = func(memory: Memory<()>, address: Nat64, struct_def: AlignedStructDefinition) : AlignedStruct {
      loadAlignedStruct(address, struct_def);
    };
    t = ();
  };
  
  func ensure(offset : Nat64) {
    let pages = (offset + Types.WASM_PAGE_SIZE) >> 16;
    if (pages > StableMemory.size()) {
      let oldsize = StableMemory.grow(pages - StableMemory.size());
      assert (oldsize != 0xFFFF_FFFF_FFFF_FFFF);
    };
  };

  func storeAlignedStruct(struct: AlignedStruct, address: Address) {
    var offset = address;
    // Ensure there is enough space to store the whole struct
    ensure(offset + AlignedStruct.size(struct));
    for(variant in Array.vals(struct)){
      switch(variant){
        case(#Nat8(value)) { StableMemory.storeNat8(offset, value);  offset += 1;                           };
        case(#Nat16(value)){ StableMemory.storeNat16(offset, value); offset += 2;                           };
        case(#Nat32(value)){ StableMemory.storeNat32(offset, value); offset += 4;                           };
        case(#Nat64(value)){ StableMemory.storeNat64(offset, value); offset += 8;                           };
        case(#Int8(value)) { StableMemory.storeInt8(offset, value);  offset += 1;                           };
        case(#Int16(value)){ StableMemory.storeInt16(offset, value); offset += 2;                           };
        case(#Int32(value)){ StableMemory.storeInt32(offset, value); offset += 4;                           };
        case(#Int64(value)){ StableMemory.storeInt64(offset, value); offset += 8;                           };
        case(#Float(value)){ StableMemory.storeFloat(offset, value); offset += 8;                           };
        case(#Blob(value)) { StableMemory.storeBlob(offset, value);  offset += Nat64.fromNat(value.size()); };
      };
    };
  };

  func loadAlignedStruct(address: Address, struct_def: AlignedStructDefinition) : AlignedStruct {
    var offset = address;
    var buffer = Buffer.Buffer<Variant>(0);
    for (variant_def in Array.vals(struct_def)){
      switch(variant_def){
        case(#Nat8)      { buffer.add(#Nat8(StableMemory.loadNat8(offset)));                    offset += 1;    };
        case(#Nat16)     { buffer.add(#Nat16(StableMemory.loadNat16(offset)));                  offset += 2;    };
        case(#Nat32)     { buffer.add(#Nat32(StableMemory.loadNat32(offset)));                  offset += 4;    };
        case(#Nat64)     { buffer.add(#Nat64(StableMemory.loadNat64(offset)));                  offset += 8;    };
        case(#Int8)      { buffer.add(#Int8(StableMemory.loadInt8(offset)));                    offset += 1;    };
        case(#Int16)     { buffer.add(#Int16(StableMemory.loadInt16(offset)));                  offset += 2;    };
        case(#Int32)     { buffer.add(#Int32(StableMemory.loadInt32(offset)));                  offset += 4;    };
        case(#Int64)     { buffer.add(#Int64(StableMemory.loadInt64(offset)));                  offset += 8;    };
        case(#Float)     { buffer.add(#Float(StableMemory.loadFloat(offset)));                  offset += 8;    };
        case(#Blob(size)){ buffer.add(#Blob(StableMemory.loadBlob(offset, Nat64.toNat(size)))); offset += size; };
      };
    };
    buffer.toArray();
  };

};