import { ethers } from "ethers";
import { pairCodeHash } from "./constants";

const sortTokens = (tokenA, tokenB) => {
  return tokenA.toLowerCase() < tokenB.toLowerCase
    ? [tokenA, tokenB]
    : [tokenB, tokenA];
};

const computePairAddress = (factory, tokenA, tokenB) => {
  [tokenA, tokenB] = sortTokens(tokenA, tokenB);

  return ethers.utils.getCreate2Address(
    factory,
    ethers.utils.keccak256(
      ethers.utils.solidityPack(["address", "address"], [tokenA, tokenB])
    ),
    pairCodeHash
  );
};

export default computePairAddress;
