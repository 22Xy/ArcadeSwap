import { ethers } from "ethers";

const uint256Max = ethers.constants.MaxUint256;

// forge inspect ArcadeSwapPair bytecode| xargs cast keccak
const pairCodeHash =
  "0xdcfe4762e3a571007d8629d1e6a9d3bbb10f19a309c88f80c88a995c89753f81";

export { uint256Max, pairCodeHash };
