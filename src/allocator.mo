import Types "types";
import Conversion "conversion";

import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";

module {

  // For convenience: from types module
  type Address = Types.Address;
  type Bytes = Types.Bytes;
  type Memory<M> = Types.Memory<M>;

  let ALLOCATOR_LAYOUT_VERSION: Nat8 = 1;
  let CHUNK_LAYOUT_VERSION: Nat8 = 1;

  let ALLOCATOR_MAGIC = "BTA";
  let CHUNK_MAGIC = "CHK";

  let NULL : Nat64 = 0;

  /// A free list constant-size chunk allocator.
  ///
  /// The allocator allocates chunks of size `allocation_size` from the given `memory`.
  ///
  /// # Properties
  ///
  /// * The allocator tries to minimize its memory footprint, growing the memory in
  ///   size only when all the available memory is allocated.
  ///
  /// * The allocator makes no assumptions on the size of the memory and will
  ///   continue growing so long as the provided `memory` allows it.
  ///
  /// The allocator divides the memory into "chunks" of equal size. Each chunk contains:
  ///     a) A `ChunkHeader` with metadata about the chunk.
  ///     b) A blob of length `allocation_size` that can be used freely by the user.
  ///
  /// # Assumptions:
  ///
  /// * The given memory is not being used by any other data structure.
  // @diff: no template type memory
  public type Allocator<M> = {
    // The address in memory where the `AllocatorHeader` is stored.
    header_addr: Address;

    // The size of the chunk to allocate in bytes.
    allocation_size: Bytes;

    // The number of chunks currently allocated.
    num_allocated_chunks: Nat64;

    // A linked list of unallocated chunks.
    free_list_head: Address;

    memory: Memory<M>;
  };

  type AllocatorHeader = {
    magic: [Nat8]; // 3 bytes
    version: Nat8;
    // Empty space to memory-align the following fields.
    _alignment: [Nat8]; // 4 bytes
    allocation_size: Bytes;
    num_allocated_chunks: Nat64;
    free_list_head: Address;
    // Additional space reserved to add new fields without breaking backward-compatibility.
    _buffer: [Nat8]; // 16 bytes
  };

  let SIZE_ALLOCATOR_HEADER : Nat64 = 48;

  /// Initialize an allocator and store it in address `addr`.
  ///
  /// The allocator assumes that all memory from `addr` onwards is free.
  ///
  /// When initialized, the allocator has the following memory layout:
  ///
  /// [   AllocatorHeader       | ChunkHeader ]
  ///      ..   free_list_head  ↑      next
  ///                |__________|       |____ NULL
  ///
  public func initAllocator<M>(memory: Memory<M>, addr: Address, allocation_size: Bytes) : Allocator<M> {
    let free_list_head = addr + SIZE_ALLOCATOR_HEADER;

    // Create the initial memory chunk and save it directly after the allocator's header.
    let chunk_header = initChunkHeader();
    let updated_memory = saveChunkHeader(chunk_header, free_list_head, memory);

    let allocator = {
      header_addr = addr;
      allocation_size;
      num_allocated_chunks: Nat64 = 0;
      free_list_head;
      memory = updated_memory;
    };

    saveAllocator(allocator);
  };

  /// Load an allocator from memory at the given `addr`.
  public func loadAllocator<M>(memory: Memory<M>, addr: Address) : Allocator<M> {
    
    let header = {
      magic                =                         memory.load(memory, addr,                         3);
      version              =                         memory.load(memory, addr + 3,                     1)[0];
      _alignment           =                         memory.load(memory, addr + 3 + 1,                 4);
      allocation_size      = Conversion.bytesToNat64(memory.load(memory, addr + 3 + 1 + 4,             8));
      num_allocated_chunks = Conversion.bytesToNat64(memory.load(memory, addr + 3 + 1 + 4 + 8,         8));
      free_list_head       = Conversion.bytesToNat64(memory.load(memory, addr + 3 + 1 + 4 + 8 + 8,     8));
      _buffer              =                         memory.load(memory, addr + 3 + 1 + 4 + 8 + 8 + 8, 16);
    };

    if (header.magic != Blob.toArray(Text.encodeUtf8(ALLOCATOR_MAGIC))) { Debug.trap("Bad magic."); };
    if (header.version != ALLOCATOR_LAYOUT_VERSION)                     { Debug.trap("Unsupported version."); };
    
    {
      header_addr = addr;
      allocation_size = header.allocation_size;
      num_allocated_chunks = header.num_allocated_chunks;
      free_list_head = header.free_list_head;
      memory = memory;
    };
  };

  /// Allocates a new chunk from memory with size `allocation_size`.
  ///
  /// Internally, there are two cases:
  ///
  /// 1) The list of free chunks (`free_list_head`) has only one element.
  ///    This case happens when we initialize a new allocator, or when
  ///    all of the previously allocated chunks are still in use.
  ///
  ///    Example memory layout:
  ///
  ///    [   AllocatorHeader       | ChunkHeader ]
  ///         ..   free_list_head  ↑      next
  ///                   |__________↑       |____ NULL
  ///
  ///    In this case, the chunk in the free list is allocated to the user
  ///    and a new `ChunkHeader` is appended to the allocator's memory,
  ///    growing the memory if necessary.
  ///
  ///    [   AllocatorHeader       | ChunkHeader | ... | ChunkHeader2 ]
  ///         ..   free_list_head      (allocated)     ↑      next
  ///                   |______________________________↑       |____ NULL
  ///
  /// 2) The list of free chunks (`free_list_head`) has more than one element.
  ///
  ///    Example memory layout:
  ///
  ///    [   AllocatorHeader       | ChunkHeader1 | ... | ChunkHeader2 ]
  ///         ..   free_list_head  ↑       next         ↑       next
  ///                   |__________↑        |___________↑         |____ NULL
  ///
  ///    In this case, the first chunk in the free list is allocated to the
  ///    user, and the head of the list is updated to point to the next free
  ///    block.
  ///
  ///    [   AllocatorHeader       | ChunkHeader1 | ... | ChunkHeader2 ]
  ///         ..   free_list_head      (allocated)      ↑       next
  ///                   |_______________________________↑         |____ NULL
  ///
  public func allocate<M>(allocator: Allocator<M>) : (Allocator<M>, Address) {
    // Get the next available chunk.
    let chunk_addr = allocator.free_list_head;
    let chunk = loadChunkHeader(chunk_addr, allocator.memory);

    // The available chunk must not be allocated.
    if (chunk.allocated) { Debug.trap("Attempting to allocate an already allocated chunk."); };

    // Allocate the chunk.
    let updated_chunk = {
      magic = chunk.magic;
      version = chunk.version;
      allocated = true;
      _alignment = chunk._alignment;
      next = chunk.next;
    };
    var updated_memory = saveChunkHeader(updated_chunk, chunk_addr, allocator.memory);

    // Update the head of the free list.
    var free_list_head = allocator.free_list_head;
    if (chunk.next != NULL) {
      // The next chunk becomes the new head of the list.
      free_list_head := chunk.next;
    } else {
      // There is no next chunk. Shift everything by chunk size.
      free_list_head += chunkSize(allocator);
      // Write new chunk to that location.
      updated_memory := saveChunkHeader(initChunkHeader(), free_list_head, allocator.memory);
    };

    let updated_allocator = {
      header_addr = allocator.header_addr;
      allocation_size = allocator.allocation_size;
      num_allocated_chunks = allocator.num_allocated_chunks + 1;
      free_list_head = free_list_head;
      memory = updated_memory;
    };

    // Return updated allocator and the chunk's address offset by the chunk's header.
    (saveAllocator(updated_allocator), chunk_addr + SIZE_CHUNK_HEADER);
  };

  /// Deallocates a previously allocated chunk.
  public func deallocate<M>(allocator: Allocator<M>, address: Address) : Allocator<M> {
    let chunk_addr = address - SIZE_CHUNK_HEADER;
    let chunk = loadChunkHeader(chunk_addr, allocator.memory);

    // The available chunk must be allocated.
    if (not chunk.allocated) { Debug.trap("Attempting to deallocate a chunk that is not allocated."); };

    // Deallocate the chunk.
    let updated_chunk = {
      magic = chunk.magic;
      version = chunk.version;
      allocated = false;
      _alignment = chunk._alignment;
      next = allocator.free_list_head;
    };
    let updated_memory = saveChunkHeader(updated_chunk, chunk_addr, allocator.memory);

    // Update the head of the free list.
    let updated_allocator = {
      header_addr = allocator.header_addr;
      allocation_size = allocator.allocation_size;
      num_allocated_chunks = allocator.num_allocated_chunks - 1;
      free_list_head = chunk_addr;
      memory = updated_memory;
    };
    
    // Return the updated allocator
    saveAllocator(updated_allocator);
  };

  /// Saves the allocator to memory.
  public func saveAllocator<M>(allocator: Allocator<M>) : Allocator<M> {
    let header = getHeader(allocator);
    let addr = allocator.header_addr;

    var updated_memory = allocator.memory;
    updated_memory := updated_memory.store(updated_memory, addr,                                                                 header.magic);
    updated_memory := updated_memory.store(updated_memory, addr + 3,                                                         [header.version]);
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1,                                                    header._alignment);
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 4,                  Conversion.nat64ToBytes(header.allocation_size));
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 4 + 8,         Conversion.nat64ToBytes(header.num_allocated_chunks));
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 4 + 8 + 8,           Conversion.nat64ToBytes(header.free_list_head));
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 4 + 8 + 8 + 8,                                       header._buffer);

    {
      header_addr = addr;
      allocation_size = allocator.allocation_size;
      num_allocated_chunks = allocator.num_allocated_chunks - 1; // @todo: why -1 ?
      free_list_head = allocator.free_list_head;
      memory = updated_memory;
    };
  };

  // The full size of a chunk, which is the size of the header + the `allocation_size` that's
  // available to the user.
  public func chunkSize<M>(allocator: Allocator<M>) : Bytes {
    allocator.allocation_size + SIZE_CHUNK_HEADER;
  };

  func getHeader<M>(allocator: Allocator<M>) : AllocatorHeader{
    {
      magic = Blob.toArray(Text.encodeUtf8(ALLOCATOR_MAGIC));
      version = ALLOCATOR_LAYOUT_VERSION;
      _alignment = [0, 0, 0, 0];
      allocation_size = allocator.allocation_size;
      num_allocated_chunks = allocator.num_allocated_chunks;
      free_list_head = allocator.free_list_head;
      _buffer = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    };
  };

  type ChunkHeader = {
    magic: [Nat8]; // 3 bytes
    version: Nat8;
    allocated: Bool;
    // Empty space to memory-align the following fields.
    _alignment: [Nat8]; // 3 bytes
    next: Address;
  };

  let SIZE_CHUNK_HEADER : Nat64 = 16;

  // Initializes an unallocated chunk that doesn't point to another chunk.
  func initChunkHeader() : ChunkHeader {
    {
      magic = Blob.toArray(Text.encodeUtf8(CHUNK_MAGIC));
      version = CHUNK_LAYOUT_VERSION;
      allocated = false;
      _alignment = [0, 0, 0];
      next = NULL;
    };
  };

  func saveChunkHeader<M>(header: ChunkHeader, addr: Address, memory: Memory<M>) : Memory<M> {
    var updated_memory = memory;
    updated_memory := updated_memory.store(updated_memory, addr,                                              header.magic);
    updated_memory := updated_memory.store(updated_memory, addr + 3,                                      [header.version]);
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1,          Conversion.boolToBytes(header.allocated));
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 1,                             header._alignment);
    updated_memory := updated_memory.store(updated_memory, addr + 3 + 1 + 1 + 3,      Conversion.nat64ToBytes(header.next));
    updated_memory;
  };

  func loadChunkHeader<M>(addr: Address, memory: Memory<M>) : ChunkHeader {
    let header = {
      magic =                            memory.load(memory, addr,                 3);
      version =                          memory.load(memory, addr + 3,             1)[0];
      allocated = Conversion.bytesToBool(memory.load(memory, addr + 3 + 1,         1));
      _alignment =                       memory.load(memory, addr + 3 + 1 + 1,     3);
      next =     Conversion.bytesToNat64(memory.load(memory, addr + 3 + 1 + 1 + 3, 8));
    };
    if (header.magic != Blob.toArray(Text.encodeUtf8(CHUNK_MAGIC))) { Debug.trap("Bad magic."); };
    if (header.version != CHUNK_LAYOUT_VERSION)                     { Debug.trap("Unsupported version."); };
    
    header;
  };

};