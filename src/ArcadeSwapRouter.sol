// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interfaces/IArcadeSwapPair.sol";
import "./interfaces/IArcadeSwapFactory.sol";
import "./ArcadeSwapLibrary.sol";

contract ArcadeSwapRouter {
    error InsufficientAAmount();
    error InsufficientBAmount();
    error SafeTransferFailed();
    error InsufficientOutputAmount();
    error ExcessiveInputAmount();

    IArcadeSwapFactory factory;

    constructor(address factoryAddress) {
        factory = IArcadeSwapFactory(factoryAddress);
    }

    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    /// @param amountADesired amounts we want to deposit into the pair. These are upper bounds.
    /// @param amountBDesired amounts we want to deposit into the pair. These are upper bounds.
    /// @param amountAMin minimal amounts we want to deposit
    /// @param amountBMin minimal amounts we want to deposit. Remember that the Pair contract always issues smaller amount of LP tokens when we deposit unbalanced liquidity? (We discussed this in Part1). So, the min parameters allow us to control how much liquidity we’re ready to lose.
    /// @param to address that receives LP-tokens
    /// @return amountA
    /// @return amountB
    /// @return liquidity
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (factory.pairs(tokenA, tokenB) == address(0)) {
            factory.createPair(tokenA, tokenB);
        }

        (amountA, amountB) = _calculateLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        address pairAddress = ArcadeSwapLibrary.pairFor(
            address(factory),
            tokenA,
            tokenB
        );

        _safeTransferFrom(tokenA, msg.sender, pairAddress, amountA);
        _safeTransferFrom(tokenB, msg.sender, pairAddress, amountB);
        liquidity = IArcadeSwapPair(pairAddress).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB) {
        address pair = ArcadeSwapLibrary.pairFor(
            address(factory),
            tokenA,
            tokenB
        );
        // sending LP-tokens to the pair and burning the exact amount of tokens.
        IArcadeSwapPair(pair).transferFrom(msg.sender, pair, liquidity);
        (amountA, amountB) = IArcadeSwapPair(pair).burn(to);
        if (amountA < amountAMin) revert InsufficientAAmount();
        if (amountB < amountBMin) revert InsufficientBAmount();
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) public returns (uint256[] memory amounts) {
        amounts = ArcadeSwapLibrary.getAmountsOut(
            address(factory),
            amountIn,
            path
        );
        if (amounts[amounts.length - 1] < amountOutMin)
            revert InsufficientOutputAmount();

        // sending fund to the first pair, so that we can iterate if we need to
        // initializes a swap by sending input tokens to the first pair
        _safeTransferFrom(
            path[0],
            msg.sender,
            ArcadeSwapLibrary.pairFor(address(factory), path[0], path[1]),
            amounts[0]
        );

        // performs chained swaps
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to
    ) public returns (uint256[] memory amounts) {
        amounts = ArcadeSwapLibrary.getAmountsIn(
            address(factory),
            amountOut,
            path
        );

        if (amounts[amounts.length - 1] > amountInMax)
            revert ExcessiveInputAmount();

        _safeTransferFrom(
            path[0],
            msg.sender,
            ArcadeSwapLibrary.pairFor(address(factory), path[0], path[1]),
            amounts[0]
        );

        _swap(amounts, path, to);
    }

    //// HELPER FUNCTIONS ////
    // In this function, we want to find the liquidity amounts that will satisfy
    // our desired and minimal amounts. Since there’s a delay between when we
    // choose liquidity amounts in UI and when our transaction gets processed,
    // actual reserves ratio might change, which will result in us losing some
    // LP-tokens (as a punishment for depositing unbalanced liquidity). By
    // selecting desired and minimal amounts, we can minimize this loss.
    function _calculateLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = ArcadeSwapLibrary.getReserves(
            address(factory),
            tokenA,
            tokenB
        );

        // if it's a new pair, which means our liquidity will define the reserves ratio,
        // which means we won’t get punished by providing unbalanced liquidity. Thus,
        // we’re allowed to deposit full desired amounts.
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = ArcadeSwapLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal <= amountBMin) revert InsufficientBAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = ArcadeSwapLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);

                if (amountAOptimal <= amountAMin) revert InsufficientAAmount();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address to_
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = ArcadeSwapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));

            address to = i < path.length - 2
                ? ArcadeSwapLibrary.pairFor(
                    address(factory),
                    output,
                    path[i + 2]
                )
                : to_;
            IArcadeSwapPair(
                ArcadeSwapLibrary.pairFor(address(factory), input, output)
            ).swap(amount0Out, amount1Out, to, "");
        }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                amount
            )
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert SafeTransferFailed();
    }
}
