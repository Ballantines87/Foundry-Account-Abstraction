# MinimalAccount (ERC-4337 Demo)

This contract implements a minimal smart account compatible with ERC-4337 Account Abstraction.  
It relies on the contract owner’s ECDSA signature for validating user operations passed through the EntryPoint.

## Features
- Implements the `IAccount` interface
- Uses `validateUserOp` to authorize operations
- Signature validation via `ECDSA.tryRecover`
- Owner-controlled account logic
- Clean and minimal reference implementation

## How It Works
The EntryPoint contract sends a `PackedUserOperation` and its hash (`userOpHash`) to `validateUserOp`.  
The account:
1. Recovers the signer from the signature inside `userOp`
2. Compares it to the `owner()`
3. Reverts if unauthorized, otherwise returns `0` to signal success

Only the owner of the contract may authorize operations.