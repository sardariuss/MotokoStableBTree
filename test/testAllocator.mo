import VecMemory "../src/memory/vecMemory";
import Allocator "../src/allocator";
import Constants "../src/constants";

import Suite "mo:matchers/Suite";

import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";

module {

  // For convenience: from base module
  type Iter<T> = Iter.Iter<T>;
  // For convenience: from matchers module
  let { run;test;suite; } = Suite;

  public class TestAllocator() = {

    func newAndLoad() {
      let memory = VecMemory.VecMemory();
      let allocator_addr = Constants.ADDRESS_0;
      let allocation_size : Nat64 = 16;

      // Create a new allocator.
      ignore Allocator.initAllocator(memory, allocator_addr, allocation_size);

      // Load it from memory.
      let allocator = Allocator.loadAllocator(memory, allocator_addr);

      assert(allocator.getAllocationSize() == allocation_size);
      assert(allocator.getFreeListHead() == (allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER));

      // Load the first memory chunk.
      let chunk = Allocator.loadChunkHeader(allocator.getFreeListHead(), memory);
      assert(chunk.next == Constants.NULL);
    };

    func allocate() {
      let memory = VecMemory.VecMemory();
      let allocator_addr = Constants.ADDRESS_0;
      let allocation_size : Nat64 = 16;

      let allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);

      let original_free_list_head = allocator.getFreeListHead();

      for (i in Iter.range(1, 3)){
        ignore allocator.allocate();
        assert(allocator.getFreeListHead() == original_free_list_head + allocator.chunkSize() * Nat64.fromNat(i));
      };
    };

    func allocateLarge() {
      // Allocate large chunks to verify that we are growing the memory.
      let memory = VecMemory.VecMemory();
      assert(memory.size() == 0);
      let allocator_addr = Constants.ADDRESS_0;
      let allocation_size = Constants.WASM_PAGE_SIZE;

      var allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);
      assert(memory.size() == 1);

      ignore allocator.allocate();
      assert(memory.size() == 2);

      ignore allocator.allocate();
      assert(memory.size() == 3);

      ignore allocator.allocate();
      assert(memory.size() == 4);

      // Each allocation should push the `head` by `chunk_size`.
      assert(allocator.getFreeListHead() == allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER + allocator.chunkSize() * 3);
      assert(allocator.getNumAllocatedChunks() == 3);

      // Load and reload to verify that the data is the same.
      allocator := Allocator.loadAllocator(memory, Constants.ADDRESS_0);
      assert(allocator.getFreeListHead() == allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER + allocator.chunkSize() * 3);
      assert(allocator.getNumAllocatedChunks() == 3);
    };

    func allocateThenDeallocate() {
      let memory = VecMemory.VecMemory();
      let allocation_size : Nat64 = 16;
      let allocator_addr = Constants.ADDRESS_0;
      var allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);
      
      let chunk_addr = allocator.allocate();
      assert(allocator.getFreeListHead() == allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER + allocator.chunkSize());
      
      allocator.deallocate(chunk_addr);
      assert(allocator.getFreeListHead() == allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER);
      assert(allocator.getNumAllocatedChunks() == 0);
      
      // Load and reload to verify that the data is the same.
      allocator := Allocator.loadAllocator(memory, allocator_addr);
      assert(allocator.getFreeListHead() == allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER);
      assert(allocator.getNumAllocatedChunks() == 0);
    };

    func allocateThenDeallocate2() {
      let memory = VecMemory.VecMemory();
      let allocation_size : Nat64 = 16;
      let allocator_addr = Constants.ADDRESS_0;
      var allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);

      ignore allocator.allocate();
      let chunk_addr_2 = allocator.allocate();
      assert(allocator.getFreeListHead() == chunk_addr_2 + allocation_size);
      
      allocator.deallocate(chunk_addr_2);
      assert(allocator.getFreeListHead() == chunk_addr_2 - Allocator.SIZE_CHUNK_HEADER);
      
      let chunk_addr_3 = allocator.allocate();
      assert(chunk_addr_3 == chunk_addr_2);
      assert(allocator.getFreeListHead() == chunk_addr_3 + allocation_size);
    };

    func deallocateFreeChunk() {
      let memory = VecMemory.VecMemory();
      let allocation_size : Nat64 = 16;
      let allocator_addr = Constants.ADDRESS_0;
      let allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);

      let chunk_addr = allocator.allocate();
      allocator.deallocate(chunk_addr);

      // Try deallocating the free chunk - should trap.
      // @todo: how to test this in motoko ?
      //allocator.deallocate(chunk_addr);
    };

    public func getSuite() : Suite.Suite {
      newAndLoad();
      allocate();
      allocateLarge();
      allocateThenDeallocate();
      allocateThenDeallocate2();
      deallocateFreeChunk();
      suite("Test allocator module", []);
    };
  };

};