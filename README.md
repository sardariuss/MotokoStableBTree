# MotokoStableBTree
https://forum.dfinity.org/t/icdevs-org-bounty-24-stablebtree-mokoko-up-to-10k/14867

## Usage

See singleBTree.mo and multipleBTrees.mo in the test/integration directory.

## Limitations
 - The MemoryManager seems to significantly slow down the execution of the BTree functions.
 - At the moment there is no way to test that a function successfully traps, so these tests are commented out.
 - The generation of documentation fails with Fatal error: exception (Invalid_argument "index out of bounds").
 - The current implementation uses the Big Endian byte order for all the serialization/deserialization. At the time of writing (2022/11/24), the Rust BTree implementation still uses some little endian (to convert size of keys/values in the node, and possibly for other structs via the use of core::slice::from_raw_parts). Hence the memory representations of the BTree in Motoko and Rust are NOT the same, i.e. it is not possible to load a BTree in Motoko that has been saved in Rust and vice-versa.

## Funding

This library was initially incentivized by [ICDevs](https://icdevs.org/). You can view more about the bounty on the [forum](https://forum.dfinity.org/t/completed-icdevs-org-bounty-24-stablebtree-mokoko-up-to-10k/14867/23) or [website](https://icdevs.org/bounties/2022/08/14/Motoko-StableBTree.html). The bounty was funded by The ICDevs.org community and the DFINITY Foundation and the award was paid to @sardariuss. If you use this library and gain value from it, please consider a [donation](https://icdevs.org/donations.html) to ICDevs