import Constants "constants";
import Utils     "utils";
import Types     "types";

import Region    "mo:base/Region";
import Blob      "mo:base/Blob";
import Int64     "mo:base/Int64";
import Buffer    "mo:base/Buffer";
import Nat64     "mo:base/Nat64";
import Array     "mo:base/Array";
import Debug     "mo:base/Debug";
import Iter      "mo:base/Iter";
import Text      "mo:base/Text";
import Nat8      "mo:base/Nat8";

import Conversion "conversion";

module {

  // For convenience: from types module
  type Memory = Types.Memory;

  type GrowFailed = {
    current_size: Nat64;
    delta: Nat64;
  };

  /// Prepare the bytes at the specified address, growing the memory size if needed.
  public func prepWrite(memory: Memory, address: Nat64, size: Nat64) {
    // Traps on overflow.
    let offset = address + size;
    // Compute the number of pages required.
    let pages = (offset + Constants.WASM_PAGE_SIZE - 1) / Constants.WASM_PAGE_SIZE;
    // Grow the number of pages if necessary.
    if (pages > memory.size()){
      let diff_pages = pages - memory.size();
      if (memory.grow(diff_pages) < 0){
        let current_size = memory.size();
        let delta = diff_pages;
        Debug.trap("Failed to grow memory from " # Nat64.toText(current_size)
          # " pages to " # Nat64.toText(current_size + delta)
          # " pages (delta = " # Nat64.toText(delta) # " pages).");
      };
    };
  };

  public func write(memory: Memory, address: Nat64, bytes: Blob) {
    prepWrite(memory, address, Nat64.fromNat(bytes.size()));
    memory.write(address, bytes);
  };


  public func writeNat8(memory: Memory, address: Nat64, v: Nat8) {
    prepWrite(memory, address, 1);
    memory.storeNat8(address, v);
  };

  public func writeNat16(memory: Memory, address: Nat64, v: Nat16) {
    prepWrite(memory, address, 2);
    memory.storeNat16(address, v);
  };

  public func writeNat32(memory: Memory, address: Nat64, v: Nat32) {
    prepWrite(memory, address, 4);
    memory.storeNat32(address, v);
  };

  public func writeNat64(memory: Memory, address: Nat64, v: Nat64) {
    prepWrite(memory, address, 8);
    memory.storeNat64(address, v);
  };


  /// Reads the bytes at the specified address, traps if exceeds memory size.
  public func read(memory: Memory, address: Nat64, size: Nat) : Blob {
    memory.read(address, size);
  };

  /// Reads the Nat8 bytes at the specified address, traps if exceeds memory size.
  public func readNat8(memory: Memory, address: Nat64) : Nat8 {
    memory.loadNat8(address);
  };

  /// Reads the Nat16 bytes at the specified address, traps if exceeds memory size.
  public func readNat16(memory: Memory, address: Nat64) : Nat16 {
    memory.loadNat16(address);
  };

  /// Reads the Nat32 bytes at the specified address, traps if exceeds memory size.
  public func readNat32(memory: Memory, address: Nat64) : Nat32 {
    memory.loadNat32(address);
  };

  /// Reads the Nat64 bytes at the specified address, traps if exceeds memory size.
  public func readNat64(memory: Memory, address: Nat64) : Nat64 {
    memory.loadNat64(address);
  };


  public class RegionMemory(r: Region.Region) : Memory {
    public func size() : Nat64 { 
      Region.size(r); 
    };
    public func grow(pages: Nat64) : Int64 {
      let old_size = Region.grow(r, pages);
      if (old_size == 0xFFFF_FFFF_FFFF_FFFF){
        return -1;
      };
      Int64.fromNat64(old_size);
    };
    public func write(address: Nat64, bytes: Blob) {
      Region.storeBlob(r, address, bytes);
    };
    public func read(address: Nat64, size: Nat) : Blob {
      Region.loadBlob(r, address, size);
    };

    public func storeNat8(address: Nat64, v: Nat8) {
      Region.storeNat8(r, address, v);
    };
    public func loadNat8(address: Nat64) : Nat8 {
      Region.loadNat8(r, address);
    };

    public func storeNat16(address: Nat64, v: Nat16) {
      Region.storeNat16(r, address, v);
    };
    public func loadNat16(address: Nat64) : Nat16 {
      Region.loadNat16(r, address);
    };

    public func storeNat32(address: Nat64, v: Nat32) {
      Region.storeNat32(r, address, v);
    };
    public func loadNat32(address: Nat64) : Nat32 {
      Region.loadNat32(r, address);
    };

    public func storeNat64(address: Nat64, v: Nat64) {
      Region.storeNat64(r, address, v);
    };
    public func loadNat64(address: Nat64) : Nat64 {
      Region.loadNat64(r, address);
    };

  };

  public class VecMemory() = this {

    // 2^64 - 1 = 18446744073709551615
    let MAX_PAGES : Nat64 = 18446744073709551615 / Constants.WASM_PAGE_SIZE;

    let buffer_ = Buffer.Buffer<Nat8>(0);

    public func size() : Nat64 {
      Nat64.fromNat(buffer_.size()) / Constants.WASM_PAGE_SIZE;
    };

    public func grow(pages: Nat64) : Int64 {
      let size = this.size();
      let num_pages = size + pages;
      // Number of pages cannot exceed defined MAX_PAGES.
      if (num_pages > MAX_PAGES) {
        return -1;
      };
      // Add the pages (initialized with zeros) to the memory buffer.
      let to_add = Array.freeze(Array.init<Nat8>(Nat64.toNat(pages * Constants.WASM_PAGE_SIZE), 0));
      buffer_.append(Utils.toBuffer(to_add));
      // Return the previous size.
      return Int64.fromIntWrap(Nat64.toNat(size));
    };

    public func read(address: Nat64, size: Nat) : Blob {
      // Traps on overflow.
      let offset = Nat64.toNat(address) + size;
      // Cannot read pass the memory buffer size.
      if (offset > buffer_.size()){
        Debug.trap("read: out of bounds");
      };
      // Copy the bytes from the memory buffer.
      let bytes = Buffer.Buffer<Nat8>(size);
      for (idx in Iter.range(Nat64.toNat(address), offset - 1)){
        bytes.add(buffer_.get(idx));
      };
      Blob.fromArray(Buffer.toArray(bytes));
    };

    public func write(address: Nat64, bytes: Blob) {
      let offset = Nat64.toNat(address) + bytes.size();
      // Check that the bytes fit into the buffer.
      if (offset > buffer_.size()){
        Debug.trap("write: out of bounds");
      };
      // Copy the given bytes in the memory buffer.
      let array = Blob.toArray(bytes);
      var idx : Nat = 0;
      for (val in Array.vals(array)){
        buffer_.put(Nat64.toNat(address) + idx, val);
        idx := idx + 1;
      };
    };

    public func toText() : Text {
      let text_buffer = Buffer.Buffer<Text>(0);
      text_buffer.add("Memory : [");
      for (byte in buffer_.vals()){
        text_buffer.add(Nat8.toText(byte) # ", ");
      };
      text_buffer.add("]");
      Text.join("", text_buffer.vals());
    };


    public func storeNat8(address: Nat64, v: Nat8) {
      write(address, Conversion.nat8ToBytes(v));
    };

    public func loadNat8(address: Nat64) : Nat8 {
      Conversion.bytesToNat8(read(address, 1));
    };

    public func storeNat16(address: Nat64, v: Nat16) {
      write(address, Conversion.nat16ToBytes(v));
    };

    public func loadNat16(address: Nat64) : Nat16 {
      Conversion.bytesToNat16(read(address, 2));
    };

    public func storeNat32(address: Nat64, v: Nat32) {
      write(address, Conversion.nat32ToBytes(v));
    };

    public func loadNat32(address: Nat64) : Nat32 {
      Conversion.bytesToNat32(read(address, 4));
    };

    public func storeNat64(address: Nat64, v: Nat64) {
      write(address, Conversion.nat64ToBytes(v));
    };

    public func loadNat64(address: Nat64) : Nat64 {
      Conversion.bytesToNat64(read(address, 8));
    };


  };

};