import Types "types";
import Conversion "conversion";

import Blob "mo:base/Blob";
import Principal "mo:base/Principal";

module {

  // For convenience: from types module
  type BytesConverter<T> = Types.BytesConverter<T>;
  
  public let NAT8_CONVERTER : BytesConverter<Nat8> = { 
    from_bytes = func(bytes: Blob) : Nat8 { return Blob.toArray(bytes)[0]; };
    to_bytes = func(nat8: Nat8) : Blob { return Blob.fromArray([nat8]); };
    max_size = 1;
    nonce = 0;
  };
  
  public let NAT16_CONVERTER : BytesConverter<Nat16> = { 
    from_bytes = Conversion.bytesToNat16;
    to_bytes = Conversion.nat16ToBytes;
    max_size = 2;
    nonce = 0;
  };
  
  public let NAT32_CONVERTER : BytesConverter<Nat32> = { 
    from_bytes = Conversion.bytesToNat32;
    to_bytes = Conversion.nat32ToBytes;
    max_size = 4;
    nonce = 0;
  };
  
  public let NAT64_CONVERTER : BytesConverter<Nat64> = { 
    from_bytes = Conversion.bytesToNat64;
    to_bytes = Conversion.nat64ToBytes;
    max_size = 8;
    nonce = 0;
  };

  public func NAT_CONVERTER(max_size: Nat32) : BytesConverter<Nat> = { 
    from_bytes = Conversion.bytesToNat;
    to_bytes = Conversion.natToBytes;
    max_size;
    nonce = 0;
  };

  public func INT_CONVERTER(max_size: Nat32) : BytesConverter<Int> = { 
    from_bytes = Conversion.bytesToInt;
    to_bytes = Conversion.intToBytes;
    max_size;
    nonce = 0;
  };
  
  //TODO: add intX converters
  
  public let BOOL_CONVERTER : BytesConverter<Bool> = { 
    from_bytes = Conversion.bytesToBool;
    to_bytes = Conversion.boolToBytes;
    max_size = 1;
    nonce = true;
  };
  
  public let EMPTY_CONVERTER : BytesConverter<()> = { 
    from_bytes = func(bytes: Blob) : () { return (); };
    to_bytes = func(empty: ()) : Blob { return Blob.fromArray([]); };
    max_size = 0;
    nonce = ();
  };
  
  public func PRINCIPAL_CONVERTER() : BytesConverter<Principal> = { 
    from_bytes = Conversion.bytesToPrincipal;
    to_bytes = Conversion.principalToBytes;
    max_size = 29;
    nonce = Principal.fromText("aaaaa-aa");
  };

  public func natConverter(max_size: Nat32) : BytesConverter<Nat> {
    {
      from_bytes = Conversion.bytesToNat;
      to_bytes = Conversion.natToBytes;
      max_size;
      nonce = 0;
    };
  };

  public func textConverter(max_size: Nat32) : BytesConverter<Text> {
    {
      from_bytes = Conversion.bytesToText;
      to_bytes = Conversion.textToBytes;
      max_size;
      nonce = "";
    };
  };

  public func bytesPassthrough(max_size: Nat32) : BytesConverter<Blob> {
    {
      from_bytes = func(bytes: Blob) : Blob { bytes; };
      to_bytes = func(bytes: Blob) : Blob { bytes; };
      max_size;
      nonce = Blob.fromArray([]);
    };
  };

  public func byteArrayConverter(max_size: Nat32) : BytesConverter<[Nat8]> {
    {
      from_bytes = func(bytes: Blob) : [Nat8] { Blob.toArray(bytes); };
      to_bytes = func(array: [Nat8]) : Blob { Blob.fromArray(array); };
      max_size;
      nonce = [];
    };
  };

};