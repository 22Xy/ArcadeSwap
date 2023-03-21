// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/ArcadeSwapPair.sol";
import "./mocks/ERC20Mintable.sol";

contract ArcadeSwapPairTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    ArcadeSwapPair pair;

    TestUser testUser;

    function setUp() public {
        testUser = new TestUser();

        token0 = new ERC20Mintable("Ether", "ETH");
        token1 = new ERC20Mintable("USD Coin", "USDC");

        pair = new ArcadeSwapPair(address(token0), address(token1));

        token0.mint(address(this), 10 ether);
        token1.mint(address(this), 10 ether);

        token0.mint(address(testUser), 10 ether);
        token1.mint(address(testUser), 10 ether);
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

    function testBurn() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        pair.burn(); // - 1 LP

        assertEq(pair.balanceOf(address(this)), 0);
        assertReserves(1000, 1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(token0.balanceOf(address(this)), 10 ether - 1000);
        assertEq(token1.balanceOf(address(this)), 10 ether - 1000);
    }

    function testBurnUnbalanced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        pair.burn();

        assertEq(pair.balanceOf(address(this)), 0);
        assertReserves(1500, 1000);
        assertEq(pair.totalSupply(), 1000);
        // What we see here is that we have lost 500 wei of token0!
        // This is the punishment for price manipulation we talked above.
        // But the amount is ridiculously small, it doesn’t seem
        // significant at all. This so because our current user
        // (the test contract) is the only liquidity provider.
        assertEq(token0.balanceOf(address(this)), 10 ether - 1500);
        assertEq(token1.balanceOf(address(this)), 10 ether - 1000);
    }

    function testBurnUnbalancedMultiUsers() public {
        // test user liquidity provision
        testUser.provideLiquidity(
            address(pair),
            address(token0),
            address(token1),
            1 ether,
            1 ether
        );
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.balanceOf(address(testUser)), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);

        // this test contract liquidity provision
        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        assertEq(pair.balanceOf(address(this)), 1 ether);

        pair.burn();

        // this user is penalized for providing unbalanced liquidity
        assertEq(pair.balanceOf(address(this)), 0);
        assertReserves(1.5 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
        // This looks completely different! We’ve now lost 0.5 ether of token0,
        // which is 1/4 of what we deposited. Now that’s a significant amount!
        assertEq(token0.balanceOf(address(this)), 10 ether - 0.5 ether);
        assertEq(token1.balanceOf(address(this)), 10 ether);

        // The testUser eventally gets that 0.5 ether since now the testUser
        // has 100% liquidity share
        assertEq(pair.balanceOf(address(testUser)), 1 ether - 1000);

        testUser.withdrawLiquidity(address(pair));
        // testUser receives the amount collected from this user
        assertEq(pair.balanceOf(address(testUser)), 0);
        // ((1 ether - 1000) * 1.5) / 1 = 1.5 ether - 1500
        assertReserves(1500, 1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(
            token0.balanceOf(address(testUser)),
            10 ether + 0.5 ether - 1500
        );
        assertEq(token1.balanceOf(address(testUser)), 10 ether - 1000);
    }

    function testBurnZeroTotalSupply() public {
        // 0x12; If you divide or modulo by zero.
        vm.expectRevert(
            hex"4e487b710000000000000000000000000000000000000000000000000000000000000012"
        );
        pair.burn();
    }

    function testBurnZeroLiquidity() public {
        // Transfer and mint as a normal user.
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);
        pair.mint();

        // Burn as a user who hasn't provided liquidity.
        // bytes memory prankData = abi.encodeWithSignature("burn()");

        vm.prank(address(0xdeadbeef));
        vm.expectRevert(bytes(hex"749383ad")); // InsufficientLiquidityBurned()
        pair.burn();
    }

    function testReservesPacking() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint();

        // Loads a storage slot from an address
        bytes32 val = vm.load(address(pair), bytes32(uint256(8)));
        assertEq(
            val,
            hex"000000000000000000001bc16d674ec800000000000000000de0b6b3a7640000"
        );
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

contract TestUser {
    function provideLiquidity(
        address pairAddress_,
        address token0Address_,
        address token1Address_,
        uint256 amount0_,
        uint256 amount1_
    ) public {
        ERC20(token0Address_).transfer(pairAddress_, amount0_);
        ERC20(token1Address_).transfer(pairAddress_, amount1_);

        ArcadeSwapPair(pairAddress_).mint();
    }

    function withdrawLiquidity(address pairAddress_) public {
        ArcadeSwapPair(pairAddress_).burn();
    }
}
