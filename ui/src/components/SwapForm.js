import "./SwapForm.css";
import { ethers } from "ethers";
import { useContext, useEffect, useState } from "react";
import { uint256Max } from "../lib/constants";
import { MetaMaskContext } from "../contexts/MetaMask";
import config from "../config.js";
import debounce from "../lib/debounce";
import AddLiquidityForm from "./AddLiquidityForm";

const SwapInput = ({
  token,
  tokens,
  onChange,
  amount,
  setAmount,
  disabled,
  readOnly,
}) => {
  return (
    <fieldset className="SwapInput" disabled={disabled}>
      <input
        type="text"
        id={token + "_amount"}
        placeholder="0.0"
        value={amount}
        onChange={(ev) => setAmount(ev.target.value)}
        readOnly={readOnly}
      />
      <select name="token" value={token} onChange={onChange}>
        {tokens.map((t) => (
          <option key={`${token}_${t.symbol}`}>{t.symbol}</option>
        ))}
      </select>
    </fieldset>
  );
};

// const defaultPairs = [
//   {
//     token0: {
//       address: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
//       symbol: "ETH",
//     },
//     token1: {
//       address: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
//       symbol: "USDC",
//     },
//   },
//   {
//     token0: {
//       address: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
//       symbol: "ETH",
//     },
//     token1: {
//       address: "0xe4e559dB9e0f4C853649b0EbabC899D1797De300",
//       symbol: "BTC",
//     },
//   },
//   {
//     token0: {
//       address: "0xe4e559dB9e0f4C853649b0EbabC899D1797De300",
//       symbol: "BTC",
//     },
//     token1: {
//       address: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
//       symbol: "USDC",
//     },
//   },
// ];

const SwapForm = () => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === "connected";
  const account = metamaskContext.account;

  const tokens = [
    {
      symbol: "ETH",
      address: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
      selected: false,
    },
    {
      symbol: "USDC",
      address: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
      selected: false,
    },
  ];

  const [amount0, setAmount0] = useState(0);
  const [amount1, setAmount1] = useState(0);
  const [tokenIn, setTokenIn] = useState();

  const [library, setLibrary] = useState();
  const [router, setRouter] = useState();
  const [pair, setPair] = useState();
  const [loading, setLoading] = useState(false);
  const [addingLiquidity, setAddingLiquidity] = useState(false);
  const path = [
    "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
  ];

  useEffect(() => {
    setLibrary(
      new ethers.Contract(
        config.libraryAddress,
        config.ABIs.ArcadeSwapLibrary,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
    setRouter(
      new ethers.Contract(
        config.routerAddress,
        config.ABIs.ArcadeSwapRouter,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
    setTokenIn(
      new ethers.Contract(
        config.wethAddress,
        config.ABIs.ERC20Mintable,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
    setPair(
      new ethers.Contract(
        config.ethUsdcPair,
        config.ABIs.ArcadeSwapPair,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
  }, []);

  /**
   * Swaps tokens by calling Router contract. Before swapping, asks users to approve spending of tokens.
   */
  const swap = (e) => {
    e.preventDefault();

    const amountIn = ethers.utils.parseEther(amount0);
    const amountOutMin = ethers.utils.parseEther(amount1);

    const token = tokenIn.attach(path[0]);

    token
      .allowance(account, config.routerAddress)
      .then((allowance) => {
        if (allowance.lt(amountIn)) {
          return token
            .approve(config.routerAddress, uint256Max)
            .then((tx) => tx.wait());
        }
      })
      .then(() => {
        return router
          .swapExactTokensForTokens(amountIn, amountOutMin, path, account)
          .then((tx) => tx.wait());
      })
      .then(() => {
        alert("Swap succeeded!");
      })
      .catch((err) => {
        console.error(err);
        alert("Failed!");
      });
  };

  /**
   * Calculates output amount by querying Router contract. Sets 'priceAfter' and 'amountOut'.
   */
  const updateAmountOut = debounce((amount) => {
    if (amount === 0 || amount === "0") {
      return;
    }

    setLoading(true);

    const amountIn = ethers.utils.parseEther(amount);

    pair.callStatic
      .getReserves()
      .then((res) => {
        library.callStatic
          .getAmountOut(amountIn, res[0], res[1])
          .then((amount) => {
            console.log(amount);
            setAmount1(ethers.utils.formatEther(amount));
            setLoading(false);
          })
          .catch((err) => {
            setLoading(false);
            console.error(err);
          });
      })
      .catch((err) => {
        setLoading(false);
        console.error(err);
      });
  });

  /**
   *  Wraps 'setAmount', ensures amount is correct, and calls 'updateAmountOut'.
   */
  const setAmountFn = (setAmountFn) => {
    return (amount) => {
      amount = amount || 0;
      setAmountFn(amount);
      updateAmountOut(amount);
    };
  };

  const toggleAddLiquidityForm = () => {
    setAddingLiquidity(!addingLiquidity);
  };

  const tokenByAddress = (address) => {
    return tokens.filter((t) => t.address === address)[0];
  };

  return (
    <section className="SwapContainer">
      {addingLiquidity && (
        <AddLiquidityForm
          toggle={toggleAddLiquidityForm}
          token0Info={tokens.filter((t) => t.address === path[0])[0]}
          token1Info={tokens.filter((t) => t.address === path[1])[0]}
        />
      )}
      <header>
        <h1>Swap tokens</h1>
        <button disabled={!enabled || loading} onClick={toggleAddLiquidityForm}>
          Add liquidity
        </button>
      </header>
      {path ? (
        <form className="SwapForm">
          <SwapInput
            amount={amount0}
            disabled={!enabled || loading}
            readOnly={false}
            setAmount={setAmountFn(setAmount0)}
            token={tokenByAddress(path[0]).symbol}
            tokens={[
              {
                symbol: "WETH",
                address: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
                selected: false,
              },
            ]}
          />
          <SwapInput
            amount={amount1}
            disabled={!enabled || loading}
            readOnly={true}
            setAmount={setAmountFn(setAmount1)}
            token={tokenByAddress(path[path.length - 1]).symbol}
            tokens={[
              {
                symbol: "USDC",
                address: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
                selected: false,
              },
            ]}
          />
          <button
            className="swap"
            disabled={!enabled || loading}
            onClick={swap}
          >
            Swap
          </button>
        </form>
      ) : (
        <span>Loading pairs...</span>
      )}
    </section>
  );
};

export default SwapForm;
