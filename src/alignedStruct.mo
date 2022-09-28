import Types "types";

import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";

module {

  // For convenience: from types module
  type Variant = Types.Variant;
  type AlignedStruct = Types.AlignedStruct;
  type AlignedStructDefinition = Types.AlignedStructDefinition;

  public func sizeVariant(variant: Variant) : Nat {
    switch(variant){
      case(#Nat8(_))   {      1;      };
      case(#Nat16(_))  {      2;      };
      case(#Nat32(_))  {      4;      };
      case(#Nat64(_))  {      8;      };
      case(#Int8(_))   {      1;      };
      case(#Int16(_))  {      2;      };
      case(#Int32(_))  {      4;      };
      case(#Int64(_))  {      8;      };
      case(#Float(_))  {      8;      };
      case(#Blob(blob)){ blob.size(); };
    };
  };
  
  public func size(struct: AlignedStruct) : Nat64 {
    var size : Nat64 = 0;
    for(variant in Array.vals(struct)){
      size += Nat64.fromNat(sizeVariant(variant));
    };
    size;
  };

  public func sizeDefinition(struct_def: AlignedStructDefinition) : Nat64 {
    var size : Nat64 = 0;
    for(variant_def in Array.vals(struct_def)){
      switch(variant_def){
        case(#Nat8)           {     size += 1;     };
        case(#Nat16)          {     size += 2;     };
        case(#Nat32)          {     size += 4;     };
        case(#Nat64)          {     size += 8;     };
        case(#Int8)           {     size += 1;     };
        case(#Int16)          {     size += 2;     };
        case(#Int32)          {     size += 4;     };
        case(#Int64)          {     size += 8;     };
        case(#Float)          {     size += 8;     };
        case(#Blob(blob_size)){ size += blob_size; };
      };
    };
    size;
  };

};