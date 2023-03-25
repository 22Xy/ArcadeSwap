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
    ERC20Mintable tokenC;
    ERC20Mintable tokenD;

    ArcadeSwapPair pair;
    ArcadeSwapPair pair2;
    ArcadeSwapPair pair3;

    // helper function
    function encodeError(
        string memory error
    ) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function setUp() public {
        factory = new ArcadeSwapFactory();

        tokenA = new ERC20Mintable("Ether", "ETH");
        tokenB = new ERC20Mintable("USD Coin", "USDC");
        tokenC = new ERC20Mintable("Bitcoin", "BTC");
        tokenD = new ERC20Mintable("USD Tether", "USDT");

        tokenA.mint(address(this), 10 ether);
        tokenB.mint(address(this), 10 ether);
        tokenC.mint(address(this), 10 ether);
        tokenD.mint(address(this), 10 ether);

        address pairAddress = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        pair = ArcadeSwapPair(pairAddress);

        pairAddress = factory.createPair(address(tokenB), address(tokenC));
        pair2 = ArcadeSwapPair(pairAddress);

        pairAddress = factory.createPair(address(tokenC), address(tokenD));
        pair3 = ArcadeSwapPair(pairAddress);
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
        assertEq(pairAddress, 0x8f1961A0aA07941702f1846EFe04290B77318875);
    }

    function testGetAmountOut() public {
        uint256 amountOut = ArcadeSwapLibrary.getAmountOut(
            1000,
            1 ether,
            1.5 ether
        );
        assertEq(amountOut, 1495);
    }

    function testGetAmountOutZeroInputAmount() public {
        vm.expectRevert(encodeError("InsufficientAmount()"));
        ArcadeSwapLibrary.getAmountOut(0, 1 ether, 1.5 ether);
    }

    function testGetAmountOutZeroInputReserve() public {
        vm.expectRevert(encodeError("InsufficientLiquidity()"));
        ArcadeSwapLibrary.getAmountOut(1000, 0, 1.5 ether);
    }

    function testGetAmountOutZeroOutputReserve() public {
        vm.expectRevert(encodeError("InsufficientLiquidity()"));
        ArcadeSwapLibrary.getAmountOut(1000, 1 ether, 0);
    }

    function testGetAmountsOut() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        tokenB.transfer(address(pair2), 1 ether);
        tokenC.transfer(address(pair2), 0.5 ether);
        pair2.mint(address(this));

        tokenC.transfer(address(pair3), 1 ether);
        tokenD.transfer(address(pair3), 2 ether);
        pair3.mint(address(this));

        address[] memory path = new address[](4);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        path[3] = address(tokenD);

        uint256[] memory amounts = ArcadeSwapLibrary.getAmountsOut(
            address(factory),
            0.1 ether,
            path
        );

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 0.1 ether);
        assertEq(amounts[1], 0.181322178776029826 ether);
        assertEq(amounts[2], 0.076550452221167502 ether);
        assertEq(amounts[3], 0.141817942760565270 ether);
    }

    function testGetAmountsOutInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert(encodeError("InvalidPath()"));
        ArcadeSwapLibrary.getAmountsOut(address(factory), 0.1 ether, path);
    }

    function testGetAmountIn() public {
        uint256 amountIn = ArcadeSwapLibrary.getAmountIn(
            1495,
            1 ether,
            1.5 ether
        );
        assertEq(amountIn, 1000);
    }

    function testGetAmountInZeroInputAmount() public {
        vm.expectRevert(encodeError("InsufficientAmount()"));
        ArcadeSwapLibrary.getAmountIn(0, 1 ether, 1.5 ether);
    }

    function testGetAmountInZeroInputReserve() public {
        vm.expectRevert(encodeError("InsufficientLiquidity()"));
        ArcadeSwapLibrary.getAmountIn(1000, 0, 1.5 ether);
    }

    function testGetAmountInZeroOutputReserve() public {
        vm.expectRevert(encodeError("InsufficientLiquidity()"));
        ArcadeSwapLibrary.getAmountIn(1000, 1 ether, 0);
    }

    function testGetAmountsIn() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        tokenB.transfer(address(pair2), 1 ether);
        tokenC.transfer(address(pair2), 0.5 ether);
        pair2.mint(address(this));

        tokenC.transfer(address(pair3), 1 ether);
        tokenD.transfer(address(pair3), 2 ether);
        pair3.mint(address(this));

        address[] memory path = new address[](4);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        path[3] = address(tokenD);

        uint256[] memory amounts = ArcadeSwapLibrary.getAmountsIn(
            address(factory),
            0.1 ether,
            path
        );

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 0.063113405152841847 ether);
        assertEq(amounts[1], 0.118398043685444580 ether);
        assertEq(amounts[2], 0.052789948793749671 ether);
        assertEq(amounts[3], 0.100000000000000000 ether);
    }

    function testGetAmountsInInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert(encodeError("InvalidPath()"));
        ArcadeSwapLibrary.getAmountsIn(address(factory), 0.1 ether, path);
    }
}
