import { createSlice } from '@reduxjs/toolkit';
import { EVENT_NEW_MSG, EVENT_NEW_TX, EVENT_WALLET_CONNECT } from '../constants/constants';
import providers from '../providers/providers';
import { tryLoadLocal, trySaveLocal } from '../utils/store';
import { createPactCommand, createSigningCommand, listenTx, localCommand, sendCommand } from '../utils/utils';
import { hideConnectWalletModal } from './connectWalletModalSlice';

const KADENA_STORE_ACCOUNT_KEY = 'KADENA_STORE_ACCOUNT_KEY';
const KADENA_STORE_PUBKEY_KEY = 'KADENA_STORE_PUBKEY_KEY';
const KADENA_STORE_PROVIDER_KEY = 'KADENA_STORE_PROVIDER_KEY';
var loadedProvider = tryLoadLocal(KADENA_STORE_PROVIDER_KEY);
var loadedAccount = tryLoadLocal(KADENA_STORE_ACCOUNT_KEY);
var loadedPubKey = tryLoadLocal(KADENA_STORE_PUBKEY_KEY);
if (loadedProvider === null) { loadedProvider = ''; }
if (loadedAccount === null) { loadedAccount = ''; }
if (loadedPubKey === null) { loadedPubKey = ''; }

export const kadenaSlice = createSlice({
  name: 'kadenaInfo',
  initialState: {
    network: import.meta.env.VITE_NETWORK,
    networkId: import.meta.env.VITE_NETWORK_ID,
    ttl: 600,
    provider: loadedProvider,
    account: loadedAccount,
    pubKey: loadedPubKey,
    transactions: [],
    newTransaction: {},
    messages: [],
    newMessage: {},
  },
  reducers: {
    setNetwork: (state, action) => {
      state.network = action.payload;
    },
    setNetworkId: (state, action) => {
      state.networkId = action.payload;
    },
    setProvider: (state, action) => {
      state.provider = action.payload;
    },
    setAccount: (state, action) => {
      state.account = action.payload;
    },
    setPubKey: (state, action) => {
      state.pubKey = action.payload;
    },
    setTransactions: (state, action) => {
      state.transactions = action.payload;
    },
    addTransaction: (state, action) => {
      state.transactions.push(action.payload);
      state.newTransaction = action.payload;
    },
    setNewTransaction: (state, action) => {
      state.newTransaction = action.payload;
    },
    addMessage: (state, action) => {
      state.messages.push(action.payload);
      state.newMessage = action.payload;
    },
    setNewMessage: (state, action) => {
      state.newMessage = action.payload;
    },
  },
})

export const { 
  setNetwork, setNetworkId, setAccount, setPubKey, 
  addTransaction, setNewTransaction, addMessage, setNewMessage
} = kadenaSlice.actions;

export default kadenaSlice.reducer;


export const connectWithProvider = (providerId) => {
  return async function(dispatch, getState) {
    let provider = providers[providerId];
    let connectResult = await provider.connect(getState);
    // console.log(connectResult);

    if (connectResult.status === 'success') {
      dispatch(kadenaSlice.actions.setProvider(providerId));
      dispatch(kadenaSlice.actions.setAccount(connectResult.account.account));
      dispatch(kadenaSlice.actions.setPubKey(connectResult.account.publicKey));
      trySaveLocal(KADENA_STORE_PROVIDER_KEY, providerId);
      trySaveLocal(KADENA_STORE_ACCOUNT_KEY, connectResult.account.account);
      trySaveLocal(KADENA_STORE_PUBKEY_KEY, connectResult.account.publicKey);
      dispatch(hideConnectWalletModal());

      const event = new CustomEvent(EVENT_WALLET_CONNECT, { detail: providerId });
      document.dispatchEvent(event);
    }
    else {
      const msg = {
        type: 'error',
        data: `Error: ${connectResult.message}. Make sure you are on ${getState().kadenaInfo.networkId}`,
      };
      const event = new CustomEvent(EVENT_NEW_MSG, { detail: msg });
      document.dispatchEvent(event);
      dispatch(kadenaSlice.actions.addMessage(msg));
    }
  }
}

export const disconnectProvider = () => {
  return async function(dispatch, getState) {
    let provider = providers[getState().kadenaInfo.provider];
    let disconnectResult = await provider.disconnect(getState);
    // console.log(disconnectResult);

    if (disconnectResult.result.status === 'success') {
      dispatch(kadenaSlice.actions.setAccount(""));
      dispatch(kadenaSlice.actions.setProvider(""));
      dispatch(kadenaSlice.actions.setPubKey(""));
      trySaveLocal(KADENA_STORE_PROVIDER_KEY, '');
      trySaveLocal(KADENA_STORE_ACCOUNT_KEY, '');
      trySaveLocal(KADENA_STORE_PUBKEY_KEY, '');

      const msg = {
        type: 'success',
        data: `Disconnected from ${provider.name}`,
      };
      const event = new CustomEvent(EVENT_NEW_MSG, { detail: msg });
      document.dispatchEvent(event);
      dispatch(kadenaSlice.actions.addMessage());
    }
    else {
      const msg = {
        type: 'error',
        data: `Error: ${disconnectResult.message}. Make sure you are on ${getState().kadenaInfo.networkId}`,
      };
      const event = new CustomEvent(EVENT_NEW_MSG, { detail: msg });
      document.dispatchEvent(event);
      dispatch(kadenaSlice.actions.addMessage(msg));
      // toast.error(`Error: ${disconnectResult.message}\nMake sure you are on: ${getState().kadenaInfo.networkId}`);
    }
  }
}

export const local = (chainId, pactCode, envData, caps=[], 
  gasLimit=15000, gasPrice=1e-5, dontUpdate=false, sign=false) => {
  return async function(dispatch, getState) {
    var cmd = {}
    if (sign) {
      let providerName = getState().kadenaInfo.provider;
      if (providerName === '') {
        const msg = {
          type: 'error',
          data: `No wallet connected`,
        };
        const event = new CustomEvent(EVENT_NEW_MSG, { detail: msg });
        document.dispatchEvent(event);
        dispatch(kadenaSlice.actions.addMessage(msg));
        return;
      }
      // console.log('got here?');
      
      let provider = providers[providerName];
      let signingCmd = createSigningCommand(
        getState, 
        chainId, 
        pactCode, 
        envData, 
        caps, 
        gasLimit, 
        gasPrice
      );
      // console.log(signingCmd);
      cmd = await provider.sign(getState, signingCmd);
    }
    else {
      cmd = createPactCommand(getState, chainId, pactCode, envData, gasLimit, gasPrice);
    }
    // console.log('cmd', cmd);

    if (dontUpdate) {
      let res = await localCommand(getState, chainId, cmd);
      // console.log(res);
      return res;
    }
    
    
    try {
      let res = await localCommand(getState, chainId, cmd);
      const e = new CustomEvent(EVENT_NEW_TX, { detail: res });
      document.dispatchEvent(e);
      dispatch(kadenaSlice.actions.addTransaction(res));
      return res;
    }
    catch (e) {
      const event = new CustomEvent(EVENT_NEW_MSG, { detail: str(e) });
      document.dispatchEvent(event);
      dispatch(kadenaSlice.actions.addMessage({
        type: 'error',
        data: `${e}`,
      }));
    }
  }
}

export const localAndSend = (chainId, pactCode, envData, 
  caps=[], gasLimit=75000, gasPrice=1e-8, b1=false, b2=false) => {
  return async function sign(dispatch, getState) {
    
    try {
      let providerName = getState().kadenaInfo.provider;
      if (providerName === '') {
        dispatch(kadenaSlice.actions.addMessage({
          type: 'error',
          data: `No wallet connected`,
        }));
        return;
      }

      let provider = providers[providerName];
      let signingCmd = createSigningCommand(
        getState, 
        chainId, 
        pactCode, 
        envData, 
        caps, 
        gasLimit, 
        gasPrice
      );
      // console.log(signingCmd);
      let signedCmd = await provider.sign(getState, signingCmd);
      let localRes = await localCommand(getState, chainId, signedCmd);
      if (localRes.result.status === 'success') {
        // console.log('signingCmd');
        // console.log(signedCmd);
        let sendRes = await sendCommand(getState, chainId, signedCmd);
        // console.log(res);

        let reqKey = sendRes.requestKeys[0];
        let reqListen = listenTx(getState, chainId, reqKey);
        let txData = {
          ...localRes,
          listenPromise: reqListen,
        };
        // console.log("tx data");
        // console.log(txData);
        dispatch(kadenaSlice.actions.addTransaction(txData));
        const e = new CustomEvent(EVENT_NEW_TX, { detail: txData });
        document.dispatchEvent(e);

        return txData;
      }
      else {
        console.log(localRes);
        const msg = {
          type: 'error',
          data: `Command failed to execute: ${localRes.result.error.message}`,
        };
        const event = new CustomEvent(EVENT_NEW_MSG, { detail: msg });
        document.dispatchEvent(event);
        dispatch(kadenaSlice.actions.addMessage(msg));
      }
    }
    catch (e) {
      const msg = {
        type: 'error',
        data: `Failed to sign command: ${e}`,
      };
      const event = new CustomEvent(EVENT_NEW_MSG, { detail: msg });
      document.dispatchEvent(event);
      dispatch(kadenaSlice.actions.addMessage(msg));
      // toast.error('Failed to sign command');
    }
  };
}

export const signAndSend = (chainId, pactCode, envData, 
  caps=[], gasLimit=75000, gasPrice=1e-8) => {
  return async function sign(dispatch, getState) {
    
    try {
      let providerName = getState().kadenaInfo.provider;
      if (providerName === '') {
        dispatch(kadenaSlice.actions.addMessage({
          type: 'error',
          data: `No wallet connected`,
        }));
        return;
      }

      let provider = providers[providerName];
      let signingCmd = createSigningCommand(
        getState, 
        chainId, 
        pactCode, 
        envData, 
        caps, 
        gasLimit, 
        gasPrice
      );
      console.log(signingCmd);
      let signedCmd = await provider.sign(getState, signingCmd);
      console.log('signingCmd');
      console.log(signedCmd);
      let res = await sendCommand(getState, chainId, signedCmd);
      // console.log(res);

      let reqKey = res.requestKeys[0];
      let reqListen = listenTx(getState, chainId, reqKey);
      let txData = {
        reqKey: reqKey,
        listenPromise: reqListen,
      };
      // console.log("tx data");
      // console.log(txData);
      dispatch(kadenaSlice.actions.addTransaction(txData));
      const e = new CustomEvent(EVENT_NEW_TX, { detail: txData });
      document.dispatchEvent(e);

      return txData;
    }
    catch (e) {
      const msg = {
        type: 'error',
        data: `Failed to sign command: ${e}`,
      };
      const event = new CustomEvent(EVENT_NEW_MSG, { detail: msg });
      document.dispatchEvent(event);
      dispatch(kadenaSlice.actions.addMessage(msg));
      // toast.error('Failed to sign command');
    }
  };
}