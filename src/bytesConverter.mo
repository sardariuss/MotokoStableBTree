import Types "types";
import Conversion "conversion";

module {

  // For convenience: from types module
  type BytesConverter<T> = Types.BytesConverter<T>;
  
  public let NAT8_CONVERTER : BytesConverter<Nat8> = { 
    fromBytes = func(bytes: [Nat8]) : Nat8 { return bytes[0]; };
    toBytes = func(nat8: Nat8) : [Nat8] { return [nat8]; };
    maxSize = func () : Nat32 { 1; };
  };
  
  public let NAT16_CONVERTER : BytesConverter<Nat16> = { 
    fromBytes = Conversion.bytesToNat16;
    toBytes = Conversion.nat16ToBytes;
    maxSize = func () : Nat32 { 2; };
  };
  
  public let NAT32_CONVERTER : BytesConverter<Nat32> = { 
    fromBytes = Conversion.bytesToNat32;
    toBytes = Conversion.nat32ToBytes;
    maxSize = func () : Nat32 { 4; };
  };
  
  public let NAT64_CONVERTER : BytesConverter<Nat64> = { 
    fromBytes = Conversion.bytesToNat64;
    toBytes = Conversion.nat64ToBytes;
    maxSize = func () : Nat32 { 8; };
  };
  
  //TODO: add intX converters
  
  public let BOOL_CONVERTER : BytesConverter<Bool> = { 
    fromBytes = Conversion.bytesToBool;
    toBytes = Conversion.boolToBytes;
    maxSize = func () : Nat32 { 1; };
  };
  
  public let EMPTY_CONVERTER : BytesConverter<()> = { 
    fromBytes = func(bytes: [Nat8]) : () { return (); };
    toBytes = func(empty: ()) : [Nat8] { return []; };
    maxSize = func () : Nat32 { 0; };
  };
  
  public let PRINCIPAL_CONVERTER : BytesConverter<Principal> = { 
    fromBytes = Conversion.bytesToPrincipal;
    toBytes = Conversion.principalToBytes;
    maxSize = func () : Nat32 { 29; };
  };

  public func natConverter(max_size: Nat32) : BytesConverter<Nat> {
    {
      fromBytes = Conversion.bytesToNat;
      toBytes = Conversion.natToBytes;
      maxSize = func () : Nat32 { max_size; };
    };
  };

  public func textConverter(max_size: Nat32) : BytesConverter<Text> {
    {
      fromBytes = Conversion.bytesToText;
      toBytes = Conversion.textToBytes;
      maxSize = func () : Nat32 { max_size; };
    };
  };

  public func bytesPassthrough(max_size: Nat32) : BytesConverter<[Nat8]> {
    {
      fromBytes = func(bytes: [Nat8]) : [Nat8] { bytes; };
      toBytes = func(bytes: [Nat8]) : [Nat8] { bytes; };
      maxSize = func () : Nat32 { max_size; };
    };
  };

};