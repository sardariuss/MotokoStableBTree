module {

  public let WASM_PAGE_SIZE : Nat64 = 65536;
  
  public let NULL : Nat64 = 0;

  public let ADDRESS_0 : Nat64 = 0; // @todo: check if equivalent to Address::from(0) in Rust implementation

  /// The minimum degree to use in the btree.
  /// This constant is taken from Rust's std implementation of BTreeMap.
  public let B : Nat = 6;

};