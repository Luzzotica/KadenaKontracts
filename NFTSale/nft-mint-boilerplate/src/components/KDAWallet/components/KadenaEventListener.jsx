import React, { useEffect } from "react";
import { EVENT_NEW_MSG, EVENT_NEW_TX, EVENT_WALLET_CONNECT } from "../constants/constants";

function KadenaEventListener(props) {
  useEffect(() => {
    const newTransactionHandler = function(e) {
      if (props.onNewTransaction) {
        props.onNewTransaction(e.detail);
      }
    };
    const newMessageHandler = function(e) {
      if (props.onNewMessage) {
        props.onNewMessage(e.detail);
      }
    };
    const walletConnectedHandler = function(e) {
      if (props.onWalletConnected) {
        props.onWalletConnected(e.detail);
      }
    };

    document.addEventListener(EVENT_NEW_TX, newTransactionHandler);
    document.addEventListener(EVENT_NEW_MSG, newMessageHandler);
    document.addEventListener(EVENT_WALLET_CONNECT, walletConnectedHandler);

    return () => {
      document.removeEventListener(EVENT_NEW_TX, newTransactionHandler);
      document.removeEventListener(EVENT_NEW_MSG, newMessageHandler);
      document.removeEventListener(EVENT_WALLET_CONNECT, walletConnectedHandler);
    }
  })

  return (
    <>
    </>
  );
}

export default KadenaEventListener;