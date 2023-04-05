import "./LiquidityForm.css";
import { ethers } from "ethers";
import { useContext, useEffect, useState } from "react";
import { uint256Max } from "../lib/constants";
import { MetaMaskContext } from "../contexts/MetaMask";
import config from "../config.js";

const BackButton = ({ onClick }) => {
  return (
    <button className="BackButton" onClick={onClick}>
      ← Back
    </button>
  );
};

const AmountInput = ({ amount, disabled, setAmount, token }) => {
  return (
    <fieldset>
      <label htmlFor={token.symbol + "_liquidity"}>{token.symbol} amount</label>
      <input
        id={token + "_liquidity"}
        onChange={(ev) => setAmount(ev.target.value)}
        placeholder="0.0"
        readOnly={disabled}
        type="text"
        value={amount}
      />
    </fieldset>
  );
};

const AddLiquidityForm = ({ toggle, token0Info, token1Info }) => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === "connected";
  const account = metamaskContext.account;
  const pairInterface = new ethers.utils.Interface(config.ABIs.ArcadeSwapPair);

  const [token0, setToken0] = useState();
  const [token1, setToken1] = useState();
  const [router, setRouter] = useState();

  const [amount0, setAmount0] = useState("0");
  const [amount1, setAmount1] = useState("0");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setToken0(
      new ethers.Contract(
        token0Info.address,
        config.ABIs.ERC20Mintable,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
    setToken1(
      new ethers.Contract(
        token1Info.address,
        config.ABIs.ERC20Mintable,
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
  }, [token0Info, token1Info]);

  /**
   * Adds liquidity to a pair. Asks user to allow spending of tokens.
   */
  const addLiquidity = (e) => {
    e.preventDefault();

    if (!token0 || !token1) {
      return;
    }

    setLoading(true);

    const amountADesired = ethers.utils.parseEther(amount0);
    const amountBDesired = ethers.utils.parseEther(amount1);
    const amountAMin = amountADesired;
    const amountBMin = amountBDesired;

    return Promise.all([
      token0.allowance(account, config.routerAddress),
      token1.allowance(account, config.routerAddress),
    ])
      .then(([allowance0, allowance1]) => {
        return Promise.resolve()
          .then(() => {
            if (allowance0.lt(amountADesired)) {
              return token0
                .approve(config.routerAddress, uint256Max)
                .then((tx) => tx.wait());
            }
          })
          .then(() => {
            if (allowance1.lt(amountBDesired)) {
              return token1
                .approve(config.routerAddress, uint256Max)
                .then((tx) => tx.wait());
            }
          })
          .then(() => {
            return router
              .addLiquidity(
                token0.address,
                token1.address,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin,
                account
              )
              .then((tx) => tx.wait());
          })
          .then(() => {
            alert("Liquidity added!");
          });
      })
      .catch((err) => {
        if (err.error && err.error.data && err.error.data.data) {
          let error;

          try {
            error = router.interface.parseError(err.error.data.data);
          } catch (e) {
            if (e.message.includes("no matching error")) {
              error = pairInterface.parseError(err.error.data.data);
            }
          }

          switch (error.name) {
            case "InsufficientAAmount":
              alert("InsufficientAAmount!");
              return;

            case "InsufficientBAmount":
              alert("InsufficientBAmount!");
              return;

            default:
              console.error(error);
              alert("Unknown error!");

              return;
          }
        }

        console.error(err);
        alert("Failed!");
      })
      .finally(() => setLoading(false));
  };

  return (
    <section className="LiquidityWrapper">
      <form className="LiquidityForm">
        <BackButton onClick={toggle} />
        <AmountInput
          amount={amount0}
          disabled={!enabled || loading}
          setAmount={setAmount0}
          token={token0Info}
        />
        <AmountInput
          amount={amount1}
          disabled={!enabled || loading}
          setAmount={setAmount1}
          token={token1Info}
        />
        <button
          className="addLiquidity"
          disabled={!enabled || loading}
          onClick={addLiquidity}
        >
          Add liquidity
        </button>
      </form>
    </section>
  );
};

export default AddLiquidityForm;
