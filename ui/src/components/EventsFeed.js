import { ethers } from "ethers";
import { useContext, useEffect, useReducer } from "react";
import { MetaMaskContext } from "../contexts/MetaMask";
import config from "../config.js";

const PairABI = require("../abi/ArcadeSwapPair.json");

const getEvents = (pair) => {
  return Promise.all([
    pair.queryFilter("Mint", "earliest", "latest"),
    pair.queryFilter("Swap", "earliest", "latest"),
  ]).then(([mints, swaps]) => {
    return Promise.resolve((mints || []).concat(swaps || []));
  });
};

const subscribeToEvents = (pair, callback) => {
  pair.on("Mint", (a, b, c, d, e, f, g, event) => callback(event));
  pair.on("Swap", (a, b, c, d, e, f, g, event) => callback(event));
};

const shortAddress = (address) =>
  address.slice(0, 6) + "..." + address.slice(-4);

const renderAmount = (amount) => {
  return ethers.utils.formatUnits(amount);
};

const renderMint = (args) => {
  return (
    <span>
      <strong>Mint =&gt; </strong>
      amounts: [{renderAmount(args.amount0)}, {renderAmount(args.amount1)}]
    </span>
  );
};

const renderSwap = (args) => {
  return (
    <span>
      <strong>Swap =&gt; </strong>
      USDC: {renderAmount(args[2])} to{" "}
      <strong>[{shortAddress(args[3])}]</strong>
    </span>
  );
};

const renderEvent = (event, i) => {
  let content;

  switch (event.event) {
    case "Mint":
      content = renderMint(event.args);
      break;

    case "Swap":
      content = renderSwap(event.args);
      break;

    default:
      return;
  }

  return (
    <tr key={i}>
      <td className="pr-2">{event.pairID}</td>
      <td>{content}</td>
    </tr>
  );
};

const isSupportedEvent = (event) => {
  return event.event === "Mint" || event.event === "Swap";
};

const cleanEvents = (events) => {
  const eventsMap = events.reduce((acc, event) => {
    acc[`${event.address}_${event.transactionHash}`] = event;
    return acc;
  }, {});

  return Object.keys(eventsMap)
    .map((k) => eventsMap[k])
    .sort((a, b) => b.blockNumber - a.blockNumber || b.logIndex - a.logIndex);
};

const eventsReducer = (state, action) => {
  switch (action.type) {
    case "add":
      return cleanEvents(state.concat(action.value));

    default:
      return;
  }
};

const EventsList = ({ events }) => {
  return (
    <div className="px-20 text-white bg-violet-500 py-6 mb-6 rounded-lg">
      <table className="">
        <tbody>{events.filter(isSupportedEvent).map(renderEvent)}</tbody>
      </table>
    </div>
  );
};

const pairID = (pair) => `${pair.token0.symbol}/${pair.token1.symbol}`;
const addPairIDToEvents = (events, pair) =>
  events
    .filter((ev) => ev)
    .map((ev) => {
      ev.pairID = pairID(pair);
      return ev;
    });

const pairs = [
  {
    address: config.ethUsdcPair,
    token0: {
      address: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
      symbol: "ETH",
    },
    token1: {
      address: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
      symbol: "USDC",
    },
  },
];

const EventsFeed = () => {
  const metamaskContext = useContext(MetaMaskContext);
  const [events, setEvents] = useReducer(eventsReducer, []);

  useEffect(() => {
    if (metamaskContext.status !== "connected") {
      return;
    }

    const pairContracts = pairs.map((pair) => {
      const contract = new ethers.Contract(
        pair.address,
        PairABI,
        new ethers.providers.Web3Provider(window.ethereum)
      );

      subscribeToEvents(contract, (event) =>
        setEvents({
          type: "add",
          value: addPairIDToEvents([event], pair),
        })
      );
      getEvents(contract).then((events) =>
        setEvents({
          type: "add",
          value: addPairIDToEvents(events, pair),
        })
      );

      return contract;
    });

    return () => {
      pairContracts.forEach((pair) => pair.removeAllListeners());
    };
  }, [metamaskContext.status, setEvents]);

  // console.log(events);

  return <EventsList events={events} />;
};

export default EventsFeed;
