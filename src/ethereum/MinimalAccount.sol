// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/* Layout of the contract file: */
// version
// imports
// interfaces, libraries, contract

// Inside Contract:
// Errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";

import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Here we're importing the IEntryPoint interface so that it will give us a better idea of how it works and it will give us the chance to get some nice getter functions as well, if we want
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

// this is just a helper constant that we can return from our validateUserOp() function to indicate whether the signature validation succeeded or failed - it's a convention from the account-abstraction library
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../../lib/account-abstraction/contracts/core/Helpers.sol";

// At some point, the EntryPoint.sol contract is gonna call this MinimalAccount contract -> and we need to set it up correctly.
// What the EntryPoint.sol contract is going to send to us is simply this PackedUserOperation -> and this PackedUserOperation is gonna have, e.g., "hey, call USDC" and approve and here's the signature and blah blah blah ...
// ... BUT also they're going to give this userOpHash (aka "user operation hash") -> and that's the hash of the entire user operation -> and it can be used as the basis for the signature

// N.B. this MinimalAccount smart contract is just gonna be an account ...
contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes returndData);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IEntryPoint immutable i_entryPointContractAddress;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier requireFromEntryPoint() {
        _requireFromEntryPoint();
        _;
    }

    // this allows both a) the EntryPoint contract and b) the owner of this MinimalAccount contract to call functions on our smart contract account MinimalAccount (e.g. directly from the owner address and not just via the EntryPoint contract - so we can have it both ways)
    modifier requireFromEntryPointOrOwner() {
        _requireFromEntryPointOrOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IEntryPoint _entryPointContractAddress) Ownable(msg.sender) {
        // Here we're making sure that only the EntryPoint contract can call our validateUserOp() function
        i_entryPointContractAddress = _entryPointContractAddress;
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/

    // remember that the receive() function is a special function in Solidity that gets called when the contract receives plain Ether (without any data) -> e.g. when someone  sends ETH with send(), transfer(), or call{value: ...}("") (that is, without data/argument inside the call(...) parentheses).

    // N.B. has to be payable to be able to receive ETH - and our contract needs to be able to receive ETH in order to pay for transactions (cause, again, we don't have a paymaster in this demo) -> so whenever the Alt Mempoo nodes send a transaction -> it's going to pull the funds from here, which we pay them in our _payPrefund() function
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           FALLBACK FUNCTION
    //////////////////////////////////////////////////////////////*/

    // remember that the fallback() function is a special function in Solidity that gets called A) when no other function matches (for example, if someone calls a function that doesn't exist on the contract) or B) when Ether is sent to the contract without any data and there's no receive() function defined.
    // e.g. if someone tries to call a function that doesn't exist on our MinimalAccount contract, the fallback() function will be executed.
    // N.B. it's a catch-all function for handling unexpected calls or transactions
    fallback() external payable {
        // Not needed for this demo
        // we can leave this empty for now -> but we could also log an event or something if we wanted to
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // ... and this validateUserOp() function is simply going to validate the user signature

    /* N.B. We will assume in this demo that a signature is valid if it's the contract owner */
    function validateUserOp(
        // In this PackedUserOperation, there's going to the be the signature -> and we need to figure out from 1) the signature that they give us and 2) the userOpHash they give us whether it does actually match or not
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds // missingAccountFunds is going to be like the fee basically -> and that's how alt-mempool nodes are gonna get paid after they send these transactions to the EntryPoint contract because they don't send it for free
    ) external requireFromEntryPoint returns (uint256 validationData) {
        // i) First, we need to validate the signature -> so we'll make a helper function _validateSignature() to do that
        validationData = _validateSignature(userOp, userOpHash);
        if (validationData != SIG_VALIDATION_SUCCESS) {
            return validationData;
        }

        // ii) Ideally, we'd also wanna validate the nonce -> we could keep track of nonces in a state variable mapping in this MinimalAccount contract -> but the actual nonce uniqueness is actually enforced by the EntryPoint contract anyway -> so for this demo, we'll skip nonce validation

        // iii) Finally, we also have to pay back money to the EntryPoint.sol contract -> so this missingAccountFunds is how much the transaction is gonna cost and how much we need to pay back to the EntryPoint contract
        // N.B. if you have a paymaster, this missingAccountFunds is gonna be zero because the paymaster is paying for it -> but we're gonna skip that

        _payPrefund(missingAccountFunds); // this _payPrefund() function is to pay back the EntryPoint contract the amount it's owed
    }

    ///
    /// @param _destinationAddress this is the destionationAddress -> e.g. AAVE or whatever
    /// @param _value this is the value in wei to send along with the call, in case it's a payable function
    /// @param _functionData this is the actual function data to call() on the destination contract -> e.g. approve(), transfer(), etc... -> and this is going to be the **ABI-encoded function data**
    function execute(
        address _destinationAddress,
        uint256 _value,
        bytes calldata _functionData
    ) external requireFromEntryPoint {
        _execute(_destinationAddress, _value, _functionData);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _validateSignature(
        PackedUserOperation calldata userOperation, // the signature is inside our PackedUserOperation and we need to validate the signature inside there against the rest of the data above it (e.g. sender, nonce, initCode, callData, etc... inside the PackedUserOperation struct)
        bytes32 userOperationHash // this "userOperationHash" is going to be the EIP-191 version of the signed hash -> and we'll need to convert this has back into just like a "normal hash" to receover the address from the signature -> and we'll use OpenZeppelin's "MessageHashUtils" library to do that and the MessageHashUtils.toEthSignedMessageHash(bytes32 messageHash) function
    ) internal view returns (uint256 validationData) {
        // In our demo, we set this up so that whoever is the owner of this MinimalAccount contract is the only one who can sign valid transactions -> so that means i) the owner of this contract should be the one to sign sender, nonce, initCode, callData, etc... and ii) the signature will be inside the "signature" field of the PackedUserOperation struct -> iii) and then we can check via the userOperationHash that the signature is valid

        // So we need to recover the address from the signature and compare it to the owner of this contract
        bytes memory signature = userOperation.signature;

        // this returns the keccak256 digest of an EIP-191 signed data with version 0x45 (aka personal_sign message) -> and after that we can use ECDSA.tryRecover() to recover the address from the signature
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(
            userOperationHash
        );

        // expectedOwner == aka the address who actually signed the hash
        (address signer, , ) = ECDSA.tryRecover(digest, signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            // pay the EntryPoint contract back the missingAccountFunds amount
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            if (!success) {
                revert();
            }
        }
    }

    function _requireFromEntryPoint() internal {
        if (msg.sender != address(i_entryPointContractAddress)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
    }

    function _requireFromEntryPointOrOwner() internal {
        if (
            msg.sender != address(i_entryPointContractAddress) &&
            msg.sender != owner()
        ) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
    }

    // this function allows us to execute the transaction information received from the EntryPoint contract after validateUserOp() has succeeded
    // this is a KEY function because this is what actually allows our MinimalAccount contract to execute arbitrary transactions on behalf of the user

    // N.B. basically this execute() is the function that, whenever we send a UserOperation to the EntryPoint contract (n.d.r. after successful validation of the UserOperation) -> we're then going to say: "Hey, you're going to need to call that execute on our MinimalAccount contract to call the dApp (e.g. on Aave, Uniswap, etc... whatever) and interact with it"
    function _execute(
        address _destinationAddress,
        uint256 _value,
        bytes calldata _functionData
    ) internal {
        (bool success, bytes memory returnData) = _destinationAddress.call{
            value: _value
        }(_functionData);

        if (!success) {
            revert MinimalAccount__CallFailed(returnData);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getEntryPointContractAddress()
        external
        view
        returns (address entryPoint)
    {
        return address(i_entryPointContractAddress);
    }
}
