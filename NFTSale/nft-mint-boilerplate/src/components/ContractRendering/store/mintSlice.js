import { createSlice } from '@reduxjs/toolkit'
import { local, localAndSend, signAndSend } from '../../KDAWallet/store/kadenaSlice';
import { createCap } from '../../KDAWallet/utils/utils';
import { getCurrentTier } from './mintSliceHelpers';

export const mintSlice = createSlice({
  name: 'mintInfo',
  initialState: {
    contract: import.meta.env.VITE_MINT_CONTRACT,
    collectionName: import.meta.env.VITE_COLLECTION_NAME,
    uriRoot: import.meta.env.VITE_COLLECTION_ROOT_URI,
    bank: '',
    collectionData: {},
    minted: 0,
    currentTier: {},
    whitelistInfo: {},
    mintedTokens: [],
    nfts: [],
  },
  reducers: {
    setCollectionData: (state, action) => {
      state.collectionData = action.payload;
    },
    setMinted: (state, action) => {
      state.minted = action.payload;
    },
    setCurrentTier: (state, action) => {
      state.currentTier = action.payload;
    },
    setWhitelistInfo: (state, action) => {
      state.whitelistInfo = action.payload;
    },
    setBank: (state, action) => {
      state.bank = action.payload;
    },
    setMintedTokens: (state, action) => {
      state.mintedTokens = action.payload;
    },
    addMintedToken: (state, action) => {
      state.mintedTokens.push(action.payload);
    },
    setNfts: (state, action) => {
      state.nfts = action.payload;
    },
    addNft: (state, action) => {
      state.nfts.push(action.payload);
    }
  },
})

export const { 
  setCollectionData, 
  setCurrentTier, 
  setBank, 
  setMintedTokens, 
  addMintedToken, 
  setNfts, 
  addNft,
} = mintSlice.actions;

export default mintSlice.reducer;

export const initMintContractData = (chainId) => {
  return async function(dispatch, getState) {
    
    let contract = getState().mintInfo.contract;
    let collectionName = getState().mintInfo.collectionName;
    // Get the available free and discount for the user
    var pactCode = `
      (${contract}.get-collection-data "${collectionName}")
    `
    // console.log(pactCode);
    var result = await dispatch(local(chainId, pactCode, {}, [], 150000, 1e-8, true));
    // console.log(result);

    if (result.result.status = 'success') {
      let collection = result.result.data;
      dispatch(mintSlice.actions.setCollectionData(collection));
      dispatch(mintSlice.actions.setMinted(collection['current-index']['int'] - 1));
      dispatch(mintSlice.actions.setCurrentTier(getCurrentTier(collection.tiers)));
      dispatch(mintSlice.actions.setBank(collection['bank-account']));
    }
    else {
      toast.error(`Failed to load contract data, error: ${result.message}.`);
    }
  }
}

export const initAccountData = (chainId, account) => {
  return async function(dispatch, getState) {
    let contract = getState().mintInfo.contract;
    let collection = getState().mintInfo.collectionName;

    // Get the bods and items for the account
    var pactCode = `
    [
      (${contract}.get-owned-for-collection "${account}" "${collection}")
      {
    `
    // Get the whitelist mint count for each tier that is a WL
    let tiers = getState().mintInfo.collectionData.tiers;
    var wlTierCount = 0;
    console.log(tiers);
    for (var i = 0; i < tiers.length; i++) {

      if (tiers[i]['tier-type'] === 'WL') {
        if (wlTierCount > 0) {
          pactCode += ',';
        }
        pactCode += `
          "${tiers[i]['tier-id']}": (${contract}.get-whitelist-mint-count "${collection}" "${tiers[i]['tier-id']}" "${account}")
        `
        wlTierCount++;
      }
    }
    pactCode += '}]'
    console.log(pactCode);

    var result = await dispatch(local(chainId, pactCode, {}, [], 150000, 1e-8, true));
    console.log(result);

    if (result.result.status = 'success') {
      // console.log(result.result.data);
      let nfts = result.result.data[0];
      dispatch(mintSlice.actions.setNfts(nfts));

      let whitelistData = result.result.data[1];
      dispatch(mintSlice.actions.setWhitelistInfo(whitelistData));
    }
    else {
      toast.error(`Failed to load user data, error: ${result.message}.`);
      return;
    }
  }
}

export const mintNft = (chainId, account, amount, price) => {
  return async function(dispatch, getState) {
    let contract = getState().mintInfo.contract;
    let minted = getState().mintInfo.minted;
    let collectionName = getState().mintInfo.collectionName;
    let bank = getState().mintInfo.bank;

    // Get the bods and items for the account
    var pactCode = `(${contract}.mint "${collectionName}" "${account}" ${amount})`;
    var caps = [
      createCap("Gas", "Allows paying for gas", "coin.GAS", []),
      createCap("MINT", "Allows minting NFTs", `${contract}.MINT`, []),
      createCap("Transfer", "Allows sending KDA to the specified address", "coin.TRANSFER", [account, bank, price * amount])
    ]
    // var result = await dispatch(local(chainId, pactCode, {}, caps, 2000 * amount, 1e-8, false, true));

    var result = await dispatch(localAndSend(chainId, 
      pactCode, 
      {}, 
      caps, 
      2000 * amount, 
      1e-8));
    console.log('Normal', result);
    
    if (result.result.status === 'success') {
      dispatch(mintSlice.actions.setMinted(minted + amount));
      for (var i = 0; i < amount; i++) {
        dispatch(mintSlice.actions.addMintedToken({
          'token-id': { int: minted + i + 1 },
          revealed: false
        }));
      }

      let currentTier = getState().mintInfo.currentTier;
      let whitelistInfo = getState().mintInfo.whitelistInfo;
      // If the whitelist info contains the current tier's tier id, 
      // increment the count
      if (whitelistInfo[currentTier['tier-id']]) {
        let info = JSON.parse(JSON.stringify(whitelistInfo));
        info[currentTier['tier-id']]['int'] += amount;
        dispatch(mintSlice.actions.setWhitelistInfo(info));
      }
    }

    
    // var result = await dispatch(signAndSend(chainId, pactCode, {}, caps, 2000 * amount, 1e-8));
    
    // dispatch(mintSlice.setMintedTokens

    // if (result.result.status = 'success') {
    //   console.log(result.result.data);
    // }
    // else {
    //   toast.error(`Failed to mint normal bod, error: ${result.message}.`);
    // }
  }
}

