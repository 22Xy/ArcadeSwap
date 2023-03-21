// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/ArcadeSwapPair.sol";
import "./mocks/ERC20Mintable.sol";

contract ArcadeSwapPairTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    ArcadeSwapPair pair;

    // TestUser testUser;

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH");
        token1 = new ERC20Mintable("USD Coin", "USDC");

        pair = new ArcadeSwapPair(address(token0), address(token1));

        token0.mint(address(this), 10 ether);
        token1.mint(address(this), 10 ether);
    }

    function testMintBootstrap() public {
        // 1 ether of token0 and 1 ether of token1 are added to the test pool.
        // As a result, 1 ether of LP-tokens is issued and we get 1 ether - 1000
        // (minus the minimal liquidity). Pool reserves and total supply get
        // updated accordingly.
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        assertReserves(1 ether, 1 ether);
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testMintWhenThereIsLiquidity() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(); // + 2 LP

        assertReserves(3 ether, 3 ether);
        assertEq(pair.balanceOf(address(this)), 3 ether - 1000);
        assertEq(pair.totalSupply(), 3 ether);
    }

    function testMintUnbalanced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        // even though user provided more token0 liquidity
        // than token1 liquidity, they still got only 1 LP-token.
        // since we take the min between tokens
        pair.mint(); // + 1 LP
        assertReserves(3 ether, 2 ether);
        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
    }

    function testMintLiquidityUnderflow() public {
        // 0x11: If an arithmetic operation results in underflow
        // or overflow outside of an unchecked { ... } block.
        vm.expectRevert(
            hex"4e487b710000000000000000000000000000000000000000000000000000000000000011"
        );
        pair.mint();
    }

    function testMintZeroInitialLiquidity() public {
        token0.transfer(address(pair), 1000);
        token1.transfer(address(pair), 1000);
        vm.expectRevert(bytes(hex"d226f9d4")); // InsufficientLiquidityMinted()
        pair.mint();
    }

    /// Helper Functions ///
    function assertReserves(
        uint112 expectedReserve0,
        uint112 expectedReserve1
    ) internal {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, expectedReserve0, "unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "unexpected reserve0");
    }
}
