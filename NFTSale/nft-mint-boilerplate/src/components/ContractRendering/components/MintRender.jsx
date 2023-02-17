import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { showConnectWalletModal } from '../../KDAWallet/store/connectWalletModalSlice';
import CustomButton from '../../Layout/CustomButton';
import FlexColumn from '../../Layout/FlexColumn';
import FlexRow from '../../Layout/FlexRow';
import { mintNft } from '../store/mintSlice';

function MintRender() {
  const chainId = import.meta.env.VITE_CHAIN_ID;

  const dispatch = useDispatch();

  const account = useSelector(state => state.kadenaInfo.account);
  const whitelistInfo = useSelector(state => state.mintInfo.whitelistInfo);
  const currentTier = useSelector(state => state.mintInfo.currentTier);
  const [price, setPrice] = useState(-1);
  const [mintCount, setMintCount] = useState(-1);
  const [mintLimit, setMintLimit] = useState(-1);
  const [remainingMints, setRemainingMints] = useState(-1);
  useEffect(() => {
    // console.log(collectionData);
    if (Object.keys(currentTier).length === 0) {
      // console.log('no collection data'); 
      return; 
    }

    // If the tier type is WL, then we need to get our mint count (if any)
    if ('tier-type' in currentTier 
      && currentTier['tier-type'] === 'WL') {
      // console.log('current tier: ', currentTier);
      // console.log('whitelist info: ', whitelistInfo);

      // Whitelisted if the tier is our whitelist 
      // and the whitelist mint count is not -1
      if (currentTier['tier-id'] in whitelistInfo
        && whitelistInfo[currentTier['tier-id']]['int'] >= 0) {
        setMintCount(whitelistInfo[currentTier['tier-id']]['int']);
        setMintLimit(currentTier['limit']);
        setPrice(currentTier.cost);
      }
      else { // If we aren't whitelisted, set the price to -1
        setMintCount(-1);
        setMintLimit(-1);
        setPrice(-1);
      }
    }
    else {
      setMintCount(-1);
      setMintLimit(-1);
      setPrice(currentTier.cost);
    }
    
  }, [currentTier, whitelistInfo]);

  useEffect(() => {
    if (mintCount === -1 || mintLimit === -1) {
      setRemainingMints(-1);
    }
    setRemainingMints(mintLimit - mintCount);
  }, [mintCount, mintLimit]);

  const [amount, setAmount] = useState(1);
  const step = (value) => {
    if (amount + value < 1 || amount + value > 10) {
      return;
    } 
    if (mintLimit !== -1 && amount + value > remainingMints) {
      return;
    }

    setAmount(amount + value);
  }

  const mint = () => {
    dispatch(mintNft(chainId, account, amount, price));
  }

  return (
    <div className="flex flex-row gap-2 justify-center place-items-center">
      <FlexColumn className="w-96 gap-4 justify-center place-items-center">
        {price >= 0 && mintCount !== -1 ? 
          <FlexColumn className="flex-auto gap-4 text-center content-center">
            <p className='text-xl'>
              {remainingMints === 0 ? 
                'No more mints for this tier!'
              : 
                `You can mint from this tier ${remainingMints}${remainingMints === 1.0 ? ' time' : ' times'}`
              }
            </p>
          </FlexColumn>
        :
          <></>
        }
        {price >= 0 || (currentTier['tier-type'] === 'WL' && remainingMints > 0) ? 
          <FlexColumn className="flex-auto w-64 gap-4 place-items-stretch">
            <FlexRow className="flex-1 gap-2 place-items-stretch">
              <CustomButton
                className='flex-auto'
                text={`-`}
                onClick={() => step(-1)}/>
              <h1 
                className='text-white text-2xl font-extrabold flex-auto text-center text-al'>
                  {amount}
              </h1>
              <CustomButton
                className='flex-auto'
                text={`+`}
                onClick={() => step(1)}/>
            </FlexRow>
            <CustomButton
              className='flex-auto'
              text={`Mint`}
              onClick={mint}/> 
          </FlexColumn>
        : 
          <></>
        }
        
      </FlexColumn>
      
    </div>
  )
}

export default MintRender;
