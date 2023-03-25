// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/ArcadeSwapFactory.sol";
import "../src/ArcadeSwapPair.sol";
import "./mocks/ERC20Mintable.sol";

contract ArcadeSwapFactoryTest is Test {
    ArcadeSwapFactory factory;

    ERC20Mintable token0;
    ERC20Mintable token1;
    ERC20Mintable token2;
    ERC20Mintable token3;

    function setUp() public {
        factory = new ArcadeSwapFactory();

        token0 = new ERC20Mintable("Ether", "ETH");
        token1 = new ERC20Mintable("USD Coin", "USDC");
        token2 = new ERC20Mintable("Bitcoin", "BTC");
        token3 = new ERC20Mintable("USD Tether", "USDT");
    }

    function encodeError(
        string memory error
    ) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function testCreatePair() public {
        address pairAddress = factory.createPair(
            address(token0),
            address(token1)
        );

        ArcadeSwapPair pair = ArcadeSwapPair(pairAddress);

        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function testCreatePairZeroAddress() public {
        vm.expectRevert(encodeError("ZeroAddress()"));
        factory.createPair(address(0), address(token0));

        vm.expectRevert(encodeError("ZeroAddress()"));
        factory.createPair(address(token1), address(0));
    }

    function testCreatePairPairExists() public {
        factory.createPair(address(token0), address(token1));

        vm.expectRevert(encodeError("PairExists()"));
        factory.createPair(address(token1), address(token0));
    }

    function testCreatePairIdenticalTokens() public {
        vm.expectRevert(encodeError("IdenticalAddresses()"));
        factory.createPair(address(token0), address(token0));
    }
}
