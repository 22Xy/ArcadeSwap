// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ArcadeSwapPair.sol";
import "./interfaces/IArcadeSwapPair.sol";

contract ArcadeSwapFactory {
    error IdenticalAddress();
    error PairExists();
    error ZeroAddress();

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    mapping(address => mapping(address => address)) public pairs;

    address[] public allPairs;

    function createPair(
        address tokenA,
        address tokenB
    ) public returns (address pair) {
        if (tokenA == tokenB) revert IdenticalAddress();

        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        if (token0 == address(0)) revert ZeroAddress();
        if (pairs[token0][token1] != address(0)) revert PairExists();

        bytes memory bytecode = type(ArcadeSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            // create and deploy a new address deterministically using bytecode + salt
            // https://docs.soliditylang.org/en/v0.5.3/yul.html?highlight=create2#low-level-functions
            // https://ethereum.stackexchange.com/questions/84842/parameters-on-evm-opcode-create/84844#84844
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IArcadeSwapPair(pair).initialize(token0, token1);

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
