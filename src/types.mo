
module {

  public type Address = Nat64;
  public type Bytes = Nat64;

  public type Variant = {
    #Nat8: Nat8;
    #Nat16: Nat16;
    #Nat32: Nat32;
    #Nat64: Nat64;
    #Int8: Int8;
    #Int16: Int16;
    #Int32: Int32;
    #Int64: Int64;
    #Float: Float;
    #Blob: Blob;
  };

  public type AlignedStruct = [Variant];

  public type VariantDefinition = {
    #Nat8;
    #Nat16;
    #Nat32;
    #Nat64;
    #Int8;
    #Int16;
    #Int32;
    #Int64;
    #Float;
    #Blob: Nat64;
  };

  public type AlignedStructDefinition = [VariantDefinition];
};