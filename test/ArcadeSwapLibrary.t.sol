// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/ArcadeSwapLibrary.sol";
import "../src/ArcadeSwapFactory.sol";
import "../src/ArcadeSwapPair.sol";
import "./mocks/ERC20Mintable.sol";

contract ArcadeSwapLibraryTest is Test {
    ArcadeSwapFactory factory;

    ERC20Mintable tokenA;
    ERC20Mintable tokenB;

    ArcadeSwapPair pair;

    function setUp() public {
        factory = new ArcadeSwapFactory();

        tokenA = new ERC20Mintable("Ether", "ETH");
        tokenB = new ERC20Mintable("USD Coin", "USDC");

        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);

        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        pair = ArcadeSwapPair(pairAddress);
    }

    function testGetReserves() public {
        tokenA.transfer(address(pair), 1.1 ether);
        tokenB.transfer(address(pair), 0.8 ether);

        ArcadeSwapPair(address(pair)).mint(address(this));

        (uint256 reserve0, uint256 reserve1) = ArcadeSwapLibrary.getReserves(
            address(factory),
            address(tokenA),
            address(tokenB)
        );

        assertEq(reserve0, 1.1 ether);
        assertEq(reserve1, 0.8 ether);
    }

    function testQuote() public {
        uint256 amountOut = ArcadeSwapLibrary.quote(1 ether, 1 ether, 1 ether);
        assertEq(amountOut, 1 ether);

        amountOut = ArcadeSwapLibrary.quote(1 ether, 2 ether, 1 ether);
        assertEq(amountOut, 0.5 ether);

        amountOut = ArcadeSwapLibrary.quote(1 ether, 1 ether, 2 ether);
        assertEq(amountOut, 2 ether);
    }

    function testPairFor() public {
        address pairAddress = ArcadeSwapLibrary.pairFor(
            address(factory),
            address(tokenA),
            address(tokenB)
        );

        assertEq(pairAddress, factory.pairs(address(tokenA), address(tokenB)));
    }

    function testPairForTokensSorting() public {
        address pairAddress = ArcadeSwapLibrary.pairFor(
            address(factory),
            address(tokenB),
            address(tokenA)
        );

        assertEq(pairAddress, factory.pairs(address(tokenA), address(tokenB)));
    }

    function testPairForNonexistentFactory() public {
        address pairAddress = ArcadeSwapLibrary.pairFor(
            address(0xaabbcc),
            address(tokenA),
            address(tokenB)
        );
        // forge test -vvvv look at trace to get this address
        assertEq(pairAddress, 0x8E64f12a6bB9dBe67474D11DD7D27883b1B9Dd40);
    }
}
