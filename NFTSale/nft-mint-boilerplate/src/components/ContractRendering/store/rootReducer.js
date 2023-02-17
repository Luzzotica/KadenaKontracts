import { combineReducers } from "redux";
import mintSlice from "./mintSlice";
import connectWalletModalSlice from "../../KDAWallet/store/connectWalletModalSlice";
import kadenaSlice from "../../KDAWallet/store/kadenaSlice";

const rootReducer = combineReducers({
  kadenaInfo: kadenaSlice,
  connectWalletModal: connectWalletModalSlice,
  mintInfo: mintSlice,
});

export default rootReducer;