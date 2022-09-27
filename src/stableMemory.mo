import Types "types";

import StableMemory "mo:base/ExperimentalStableMemory";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

module {

  // For convenience: from types module
  type Address = Types.Address;
  type Variant = Types.Variant;
  type AlignedStruct = Types.AlignedStruct;
  type AlignedStructDefinition = Types.AlignedStructDefinition;
  
  let WASM_PAGE_SIZE : Nat64 = 65536;

  func ensure(offset : Nat64) {
    let pages = (offset + WASM_PAGE_SIZE) >> 16;
    if (pages > StableMemory.size()) {
      let oldsize = StableMemory.grow(pages - StableMemory.size());
      assert (oldsize != 0xFFFF_FFFF_FFFF_FFFF);
    };
  };

  public func sizeAlignedStruct(struct: AlignedStruct) : Nat64 {
    var size : Nat64 = 0;
    for(variant in Array.vals(struct)){
      switch(variant){
        case(#Nat8(_))   { size += 1;                          };
        case(#Nat16(_))  { size += 2;                          };
        case(#Nat32(_))  { size += 4;                          };
        case(#Nat64(_))  { size += 8;                          };
        case(#Int8(_))   { size += 1;                          };
        case(#Int16(_))  { size += 2;                          };
        case(#Int32(_))  { size += 4;                          };
        case(#Int64(_))  { size += 8;                          };
        case(#Float(_))  { size += 8;                          };
        case(#Blob(blob)){ size += Nat64.fromNat(blob.size()); };
      };
    };
    size;
  };

  public func sizeAlignedStructDefinition(struct_def: AlignedStructDefinition) : Nat64 {
    var size : Nat64 = 0;
    for(variant_def in Array.vals(struct_def)){
      switch(variant_def){
        case(#Nat8)           { size += 1;         };
        case(#Nat16)          { size += 2;         };
        case(#Nat32)          { size += 4;         };
        case(#Nat64)          { size += 8;         };
        case(#Int8)           { size += 1;         };
        case(#Int16)          { size += 2;         };
        case(#Int32)          { size += 4;         };
        case(#Int64)          { size += 8;         };
        case(#Float)          { size += 8;         };
        case(#Blob(blob_size)){ size += blob_size; };
      };
    };
    size;
  };

  public func saveAlignedStruct(struct: AlignedStruct, address: Address) {
    var offset = address;
    // Ensure there is enough space to store the whole struct
    ensure(offset + sizeAlignedStruct(struct));
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

  public func loadAlignedStruct(address: Address, struct_def: AlignedStructDefinition) : AlignedStruct {
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