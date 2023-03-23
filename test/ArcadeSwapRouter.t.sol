// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/ArcadeSwapFactory.sol";
import "../src/ArcadeSwapPair.sol";
import "../src/ArcadeSwapRouter.sol";
import "./mocks/ERC20Mintable.sol";

contract ArcadeSwapRouterTest is Test {
    ArcadeSwapFactory factory;
    ArcadeSwapRouter router;

    ERC20Mintable tokenA;
    ERC20Mintable tokenB;

    function setUp() public {
        factory = new ArcadeSwapFactory();
        router = new ArcadeSwapRouter(address(factory));

        tokenA = new ERC20Mintable("Ether", "ETH");
        tokenB = new ERC20Mintable("USD Coin", "USDC");

        tokenA.mint(address(this), 20 ether);
        tokenB.mint(address(this), 20 ether);
    }

    function encodeError(
        string memory error
    ) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function testAddLiquidityCreatesPair() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = factory.pairs(address(tokenA), address(tokenB));
        assertEq(pairAddress, 0x7BbC68Ad1A7e34f9780029543F1B11555fA6b3d1);
    }

    function testAddLiquidityNoPair() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tokenA),
                address(tokenB),
                1 ether,
                1 ether,
                1 ether,
                1 ether,
                address(this)
            );

        assertEq(amountA, 1 ether);
        assertEq(amountB, 1 ether);
        assertEq(liquidity, 1 ether - 1000);

        address pairAddress = factory.pairs(address(tokenA), address(tokenB));

        assertEq(tokenA.balanceOf(pairAddress), 1 ether);
        assertEq(tokenB.balanceOf(pairAddress), 1 ether);

        ArcadeSwapPair pair = ArcadeSwapPair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));
        assertEq(pair.totalSupply(), 1 ether);
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);

        assertEq(tokenA.balanceOf(address(this)), 19 ether);
        assertEq(tokenB.balanceOf(address(this)), 19 ether);
    }

    function testAddLiquidityAmountBOptimalIsOk() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );

        ArcadeSwapPair pair = ArcadeSwapPair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 1 ether);
        tokenB.transfer(pairAddress, 2 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tokenA),
                address(tokenB),
                1 ether,
                2 ether,
                1 ether,
                1.9 ether,
                address(this)
            );

        assertEq(amountA, 1 ether);
        assertEq(amountB, 2 ether);
        assertEq(liquidity, 1414213562373095048);
    }

    function testAddLiquidityAmountBOptimalIsTooLow() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );

        ArcadeSwapPair pair = ArcadeSwapPair(pairAddress);
        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 5 ether);
        tokenB.transfer(pairAddress, 10 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        vm.expectRevert(encodeError("InsufficientBAmount()"));
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1 ether,
            2 ether,
            1 ether,
            2 ether,
            address(this)
        );
    }

    function testAddLiquidityAmountBOptimalTooHighAmountATooLow() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        ArcadeSwapPair pair = ArcadeSwapPair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 10 ether);
        tokenB.transfer(pairAddress, 5 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 2 ether);
        tokenB.approve(address(router), 1 ether);

        vm.expectRevert(encodeError("InsufficientAAmount()"));
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            2 ether,
            0.9 ether,
            2 ether,
            1 ether,
            address(this)
        );
    }

    function testAddLiquidityAmountBOptimalIsTooHighAmountAOk() public {
        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        ArcadeSwapPair pair = ArcadeSwapPair(pairAddress);

        assertEq(pair.token0(), address(tokenB));
        assertEq(pair.token1(), address(tokenA));

        tokenA.transfer(pairAddress, 10 ether);
        tokenB.transfer(pairAddress, 5 ether);
        pair.mint(address(this));

        tokenA.approve(address(router), 2 ether);
        tokenB.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tokenA),
                address(tokenB),
                2 ether,
                0.9 ether,
                1.7 ether,
                1 ether,
                address(this)
            );
        assertEq(amountA, 1.8 ether);
        assertEq(amountB, 0.9 ether);
        assertEq(liquidity, 1272792206135785543);
    }
}
