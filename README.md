# MotokoStableBTree
https://forum.dfinity.org/t/icdevs-org-bounty-24-stablebtree-mokoko-up-to-10k/14867

## Usage

See singleBTree.mo and multipleBTrees.mo in the test/integration directory.

## Limitations
 - The MemoryManager seems to significantly slow down the execution of the BTree functions.
 - At the moment there is no way to test that a function successfully traps, so these tests are commented out.
 - The generation of documentation fails with Fatal error: exception (Invalid_argument "index out of bounds").
 - The current implementation uses the Big Endian byte order for all the serialization/deserialization. At the time of writing (2022/11/24), the Rust BTree implementation still uses some little endian (to convert size of keys/values in the node, and possibly for other structs via the use of core::slice::from_raw_parts). Hence the memory representation of the BTree in Motoko and Rust is NOT the same, i.e. it is not possible to load a BTree in Motoko that has been saved in Rust and vice-versa.