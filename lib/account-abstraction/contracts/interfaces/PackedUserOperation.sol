// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.5;

/**
 * User Operation struct
 * @param sender                - The sender account of this request.
 * @param nonce                 - Unique value the sender uses to verify it is not a replay.
 * @param initCode              - If set, the account contract will be created by this constructor/
 * @param callData              - The method call to execute on this account.
 * @param accountGasLimits      - Packed gas limits for validateUserOp and gas limit passed to the callData method call.
 * @param preVerificationGas    - Gas not calculated by the handleOps method, but added to the gas paid.
 *                                Covers batch overhead.
 * @param gasFees               - packed gas fields maxPriorityFeePerGas and maxFeePerGas - Same as EIP-1559 gas parameters.
 * @param paymasterAndData      - If set, this field holds the paymaster address, verification gas limit, postOp gas limit and paymaster-specific extra data
 *                                The paymaster will pay for the transaction instead of the sender.
 * @param signature             - Sender-verified signature over the entire request, the EntryPoint address and the chain ID.
 */
struct PackedUserOperation {
    address sender; // our MinimalAccount contract address
    uint256 nonce;
    bytes initCode; // ignore
    bytes callData; // this is were we put "the good stuff" -> this is where we say, e.g., our MinimalAccount contract should approve USDC for 50 tokens or transfer or whatever -> that is, this is the actual meat of the transaction
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData; // by default MinimalAccount pays the Alt Mempool Nodes for gas, so there needs to be funds inside the MinimalAccount contract to pay-> but if we use a paymaster (that is, if you customize somebody else to pay for YOUR transactions), then the paymaster will pay for the gas instead of the MinimalAccount contract -> and this is where we put the data for the paymaster
    bytes signature; // this is where the signature goes -> and the signature is signing the whole chunk of data above (e.g. sender, nonce, initCode, callData, etc) -> and we're going to CUSTOMIZE in our MinimalAccount contract WHAT IS A VALID SIGNATURE
}
