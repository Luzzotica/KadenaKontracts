import React, { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import { X_WALLET, ZELCORE } from "../providers/providers";
import { connectWithProvider } from "../store/kadenaSlice";
import { hideConnectWalletModal } from "../store/connectWalletModalSlice";

function ConnectWalletModal(props) {
  const dispatch = useDispatch();
  const shouldShow = useSelector(state => state.connectWalletModal.showing);

  const closeModal = () => {
    dispatch(hideConnectWalletModal());
  }

  const connectXWalletClicked = () => {
    dispatch(connectWithProvider(X_WALLET));
  }

  const connectZelcoreClicked = () => {
    dispatch(connectWithProvider(ZELCORE));
  }

  if (!shouldShow) {
    return null;
  }

  const modalStyle = props.modalStyle;
  const buttonStyle = props.buttonStyle;

  return (
    <div className={`z-50 bg-blend-darken bg-black bg-opacity-50 transition duration-300 ease-in-out fixed top-0 left-0 w-full h-full overflow-x-hidden overflow-y-auto flex flex-col justify-center place-items-center ${props.className}`}>
      {/* <div className="w-full flex flex-row justify-center pointer-events-none"> */}
      <div className={modalStyle}>
        <div className="flex flex-row justify-between gap-10">
          <span className="text-3xl">Connect Wallet</span>
          <button
            className="text-3xl bg-transparent"
            onClick={closeModal}
          >X</button>
        </div>
        <button
          className={buttonStyle}
          onClick={connectXWalletClicked}>
          X WALLET
        </button>
        <button
          className={buttonStyle}
          onClick={connectZelcoreClicked}>
          ZELCORE
        </button>
      </div>
      {/* </div> */}
    </div >
  );
}

export default ConnectWalletModal;