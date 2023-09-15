import Memory           "../../src/memory";
import Allocator        "../../src/allocator";
import Constants        "../../src/constants";
import { Test }         "testableItems";

import { test; suite; } "mo:test";

import Nat64            "mo:base/Nat64";
import Iter             "mo:base/Iter";

suite("Allocator test suite", func() {

  // For convenience: from base module
  type Iter<T> = Iter.Iter<T>;

  test("newAndLoad", func() {
    let memory = Memory.VecMemory();
    let allocator_addr = Constants.ADDRESS_0;
    let allocation_size : Nat64 = 16;

    // Create a new allocator.
    ignore Allocator.initAllocator(memory, allocator_addr, allocation_size);

    // Load it from memory.
    let allocator = Allocator.loadAllocator(memory, allocator_addr);

    Test.equalsNat64(allocator.getAllocationSize(), allocation_size);
    Test.equalsNat64(allocator.getFreeListHead(), allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER);

    // Load the first memory chunk.
    let chunk = Allocator.loadChunkHeader(allocator.getFreeListHead(), memory);
    Test.equalsNat64(chunk.next, Constants.NULL);
  });

  test("allocate", func() {
    let memory = Memory.VecMemory();
    let allocator_addr = Constants.ADDRESS_0;
    let allocation_size : Nat64 = 16;

    let allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);

    let original_free_list_head = allocator.getFreeListHead();

    for (i in Iter.range(1, 3)){
      ignore allocator.allocate();
      Test.equalsNat64(allocator.getFreeListHead() , original_free_list_head + allocator.chunkSize() * Nat64.fromNat(i));
    };
  });

  test("allocateLarge", func() {
    // Allocate large chunks to verify that we are growing the memory.
    let memory = Memory.VecMemory();
    Test.equalsNat64(memory.size() , 0);
    let allocator_addr = Constants.ADDRESS_0;
    let allocation_size = Constants.WASM_PAGE_SIZE;

    var allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);
    Test.equalsNat64(memory.size() , 1);

    ignore allocator.allocate();
    Test.equalsNat64(memory.size() , 2);

    ignore allocator.allocate();
    Test.equalsNat64(memory.size() , 3);

    ignore allocator.allocate();
    Test.equalsNat64(memory.size() , 4);

    // Each allocation should push the `head` by `chunk_size`.
    Test.equalsNat64(allocator.getFreeListHead() , allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER + allocator.chunkSize() * 3);
    Test.equalsNat64(allocator.getNumAllocatedChunks() , 3);

    // Load and reload to verify that the data is the same.
    allocator := Allocator.loadAllocator(memory, Constants.ADDRESS_0);
    Test.equalsNat64(allocator.getFreeListHead() , allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER + allocator.chunkSize() * 3);
    Test.equalsNat64(allocator.getNumAllocatedChunks() , 3);
  });

  test("allocateThenDeallocate", func() {
    let memory = Memory.VecMemory();
    let allocation_size : Nat64 = 16;
    let allocator_addr = Constants.ADDRESS_0;
    var allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);
    
    let chunk_addr = allocator.allocate();
    Test.equalsNat64(allocator.getFreeListHead() , allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER + allocator.chunkSize());
    
    allocator.deallocate(chunk_addr);
    Test.equalsNat64(allocator.getFreeListHead() , allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER);
    Test.equalsNat64(allocator.getNumAllocatedChunks() , 0);
    
    // Load and reload to verify that the data is the same.
    allocator := Allocator.loadAllocator(memory, allocator_addr);
    Test.equalsNat64(allocator.getFreeListHead() , allocator_addr + Allocator.SIZE_ALLOCATOR_HEADER);
    Test.equalsNat64(allocator.getNumAllocatedChunks() , 0);
  });

  test("allocateThenDeallocate2", func() {
    let memory = Memory.VecMemory();
    let allocation_size : Nat64 = 16;
    let allocator_addr = Constants.ADDRESS_0;
    var allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);

    ignore allocator.allocate();
    let chunk_addr_2 = allocator.allocate();
    Test.equalsNat64(allocator.getFreeListHead() , chunk_addr_2 + allocation_size);
    
    allocator.deallocate(chunk_addr_2);
    Test.equalsNat64(allocator.getFreeListHead() , chunk_addr_2 - Allocator.SIZE_CHUNK_HEADER);
    
    let chunk_addr_3 = allocator.allocate();
    Test.equalsNat64(chunk_addr_3 , chunk_addr_2);
    Test.equalsNat64(allocator.getFreeListHead() , chunk_addr_3 + allocation_size);
  });

  test("deallocateFreeChunk", func() {
    let memory = Memory.VecMemory();
    let allocation_size : Nat64 = 16;
    let allocator_addr = Constants.ADDRESS_0;
    let allocator = Allocator.initAllocator(memory, allocator_addr, allocation_size);

    let chunk_addr = allocator.allocate();
    allocator.deallocate(chunk_addr);

    // Try deallocating the free chunk - should trap.
    // TODO: succeed on trap
    //allocator.deallocate(chunk_addr);
  });
  
});
