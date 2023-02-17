
import { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { ToastContainer } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import ConnectWalletModal from '../KDAWallet/components/ConnectWalletModal';
import KadenaEventListener from '../KDAWallet/components/KadenaEventListener';
import { showConnectWalletModal } from '../KDAWallet/store/connectWalletModalSlice';
import { disconnectProvider } from '../KDAWallet/store/kadenaSlice';
import reduceToken from '../KDAWallet/utils/reduceToken';
import CustomButton from '../Layout/CustomButton';
import FlexColumn from '../Layout/FlexColumn';
import { messageToastManager, txToastManager, walletConnectedToastManager } from '../TxToast/TxToastManager';
import MintContractRender from './components/MintContractRender';
import MintRender from './components/MintRender';
import NftList from './components/NftList';
import { initAccountData, initMintContractData } from './store/mintSlice';

import './index.css'

function MintPage() {
  const chainId = import.meta.env.VITE_CHAIN_ID

  const dispatch = useDispatch();
  const account = useSelector(state => state.kadenaInfo.account);
  const bank = useSelector(state => state.mintInfo.bank);

  const initData = async () => { 
    await dispatch(initMintContractData(chainId));
  }

  useEffect(() => {
    initData();
  }, []);

  const initAccount = async () => {
    await dispatch(initAccountData(chainId, account));
  }

  useEffect(() => {
    if (account !== '' && bank !== '') {
      initAccount();
    }
  }, [account, bank]);

  const openModal = () => {
    dispatch(showConnectWalletModal());
  }

  const disconnect = () => {
    dispatch(disconnectProvider());
  } 

  return (
    <div className='h-auto'>
      <ToastContainer />
      <KadenaEventListener
        onNewTransaction={txToastManager}
        onNewMessage={messageToastManager}
        onWalletConnected={walletConnectedToastManager}/>
      <ConnectWalletModal
        className="text-white" 
        modalStyle="border-white border rounded-3xl py-4 px-8 shadow-lg min-w-max max-w-xl flex flex-col space-y-4 bg-slate-800"
        buttonStyle="bg-yellow-500 border-slate-100 border py-2 px-4 rounded-3xl hover:border-slate-300 active:border-slate-700 focus:border-slate-500 transition duration-150 ease-out"
      />
      <FlexColumn className='gap-2 fixed px-2 bottom-2 z-10 w-full sm:w-48 place-items-center sm:place-items-start'>
        <div className="w-20 text-center rounded-3xl bg-slate-900 py-1 px-1">
          <span className="text-sm text-white">Chain {chainId}</span>
        </div>
        {account !== '' ? 
          <FlexColumn className='w-max sm:w-auto gap-1 rounded-3xl bg-slate-900 py-2 px-2'>
            <CustomButton
              className='text-white'
              text={"Disconnect"}
              onClick={disconnect} /> 
            <p className='flex-1 text-center text-white'>{reduceToken(account)}</p>
          </FlexColumn>
          : 
          <></>
        }
      </FlexColumn>
      <div className='hero bg-zinc-800 bg-hero bg-cover bg-right bg-no-repeat text-white py-10'>
        <FlexColumn className='gap-10'>
          <FlexColumn className='gap-10 bg-opacity-50 bg-black rounded-3xl p-4 m-4'>
            <MintContractRender/>
            {account === '' ? 
              <div className='flex flex-col place-items-center'>
                <CustomButton
                  className='w-64'
                  text={"Connect Wallet"}
                  onClick={openModal} /> 
              </div>
            : 
              <MintRender/>
            }
          </FlexColumn>
        </FlexColumn>
      </div>
      <div className='h-auto'>
        <div className='bg-minted bg-contain bg-no-repeat sticky top-0 h-64 mg:h-full -z-10'></div>
        <NftList className='-mt-40 pb-40'/>
      </div>
    </div>
  )
}

export default MintPage