// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/console.sol";
import "forge-std/Script.sol";

import "../src/ArcadeSwapLibrary.sol";
import "../src/ArcadeSwapFactory.sol";
import "../src/ArcadeSwapPair.sol";
import "../src/ArcadeSwapRouter.sol";
import "./mocks/ERC20Mintable.sol";

contract DeployDevelopment is Script {
    ArcadeSwapFactory factory;
    ArcadeSwapRouter router;

    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    ERC20Mintable tokenC;

    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    function run() public {
        // DEPLOYING STARGED
        vm.startBroadcast();

        factory = new ArcadeSwapFactory();
        router = new ArcadeSwapRouter(address(factory));

        tokenA = new ERC20Mintable("Ether", "ETH");
        tokenB = new ERC20Mintable("USD Coin", "USDC");
        tokenC = new ERC20Mintable("Bitcoin", "BTC");

        tokenA.mint(user1, 2000 ether);
        tokenB.mint(user1, 2000 ether);
        tokenC.mint(user1, 2000 ether);

        tokenA.mint(user2, 2000 ether);
        tokenB.mint(user2, 2000 ether);
        tokenC.mint(user2, 2000 ether);

        address ETH_USDC_PAIR = factory.createPair(
            address(tokenA),
            address(tokenB)
        );
        address ETH_BTC_PAIR = factory.createPair(
            address(tokenA),
            address(tokenC)
        );
        address BTC_USDC_PAIR = factory.createPair(
            address(tokenC),
            address(tokenB)
        );

        vm.stopBroadcast();
        // DEPLOYING DONE

        console.log("ETH address", address(tokenA));
        console.log("USDC address", address(tokenB));
        console.log("BTC address", address(tokenC));

        console.log("Factory address", address(factory));
        console.log("Router address", address(router));
        console.log("Library address", address(ArcadeSwapLibrary));

        console.log("ETH USDC pair address", ETH_USDC_PAIR);
        console.log("ETH BTC pair address", ETH_BTC_PAIR);
        console.log("BTC USDC pair address", BTC_USDC_PAIR);
    }
}
