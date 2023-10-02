import Types      "types";
import Conversion "conversion";

import Blob       "mo:base/Blob";
import Principal  "mo:base/Principal";

module {

  public type BytesConverter<T> = Types.BytesConverter<T>;
  
  public let n8conv : BytesConverter<Nat8> = { 
    from_bytes = func(bytes: Blob) : Nat8 { return Blob.toArray(bytes)[0]; };
    to_bytes = func(nat8: Nat8) : Blob { return Blob.fromArray([nat8]); };
    max_size = 1;
    nonce = 0;
  };
  
  public let n16conv : BytesConverter<Nat16> = { 
    from_bytes = Conversion.bytesToNat16;
    to_bytes = Conversion.nat16ToBytes;
    max_size = 2;
    nonce = 0;
  };
  
  public let n32conv : BytesConverter<Nat32> = { 
    from_bytes = Conversion.bytesToNat32;
    to_bytes = Conversion.nat32ToBytes;
    max_size = 4;
    nonce = 0;
  };
  
  public let n64conv : BytesConverter<Nat64> = { 
    from_bytes = Conversion.bytesToNat64;
    to_bytes = Conversion.nat64ToBytes;
    max_size = 8;
    nonce = 0;
  };

  public func nconv(max_size: Nat32) : BytesConverter<Nat> = { 
    from_bytes = Conversion.bytesToNat;
    to_bytes = Conversion.natToBytes;
    max_size;
    nonce = 0;
  };

  public func iconv(max_size: Nat32) : BytesConverter<Int> = { 
    from_bytes = Conversion.bytesToInt;
    to_bytes = Conversion.intToBytes;
    max_size;
    nonce = 0;
  };
  
  //TODO: add intX converters
  
  public let bconv : BytesConverter<Bool> = { 
    from_bytes = Conversion.bytesToBool;
    to_bytes = Conversion.boolToBytes;
    max_size = 1;
    nonce = true;
  };
  
  public let emptyconv : BytesConverter<()> = { 
    from_bytes = func(bytes: Blob) : () { return (); };
    to_bytes = func(empty: ()) : Blob { return Blob.fromArray([]); };
    max_size = 0;
    nonce = ();
  };
  
  public func pconv() : BytesConverter<Principal> = { 
    from_bytes = Conversion.bytesToPrincipal;
    to_bytes = Conversion.principalToBytes;
    max_size = 29;
    nonce = Principal.fromText("aaaaa-aa");
  };

  public func tconv(max_size: Nat32) : BytesConverter<Text> = {
    from_bytes = Conversion.bytesToText;
    to_bytes = Conversion.textToBytes;
    max_size;
    nonce = "";
  };

  public func n8aconv(max_size: Nat32) : BytesConverter<[Nat8]> = {
    from_bytes = func(bytes: Blob) : [Nat8] { Blob.toArray(bytes); };
    to_bytes = func(array: [Nat8]) : Blob { Blob.fromArray(array); };
    max_size;
    nonce = [0];
  };

  public func noconv(max_size: Nat32) : BytesConverter<Blob> = {
    from_bytes = func(bytes: Blob) : Blob { bytes; };
    to_bytes = func(bytes: Blob) : Blob { bytes; };
    max_size;
    nonce = Blob.fromArray([0]);
  };

};