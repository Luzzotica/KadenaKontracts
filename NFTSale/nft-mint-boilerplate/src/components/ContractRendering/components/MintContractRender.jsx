import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import FlexColumn from '../../Layout/FlexColumn';
import FlexRow from '../../Layout/FlexRow';
import { setCurrentTier } from '../store/mintSlice';
import { formatCountdown, getCurrentTier } from '../store/mintSliceHelpers';

function MintContractRender() {

  const dispatch = useDispatch();

  const collectionData = useSelector(state => state.mintInfo.collectionData);
  const [collectionStatus, setCollectionStatus] = useState('');
  const minted = useSelector(state => state.mintInfo.minted);
  const [totalSupply, setTotalSupply] = useState(0);
  useEffect(() => {
    if (Object.keys(collectionData).length === 0) {
      return;
    }

    // console.log(collectionData);
    let totalSupply = collectionData['total-supply']['int'];
    setTotalSupply(totalSupply);

    if (totalSupply === minted) {
      setCollectionStatus('complete');
    }
  }, [collectionData]);

  

  const currentTier = useSelector(state => state.mintInfo.currentTier);
  const [timerStatus, setTimerStatus] = useState('before');
  const [tierName, setTierName] = useState('');
  const [endTime, setEndTime] = useState(new Date());
  const [priceText, setPriceText] = useState('');
  useEffect(() => {
    // console.log(collectionData);
    if (Object.keys(currentTier).length === 0) {
      // console.log('no collection data'); 
      return;
    }
    let tierId = currentTier['tier-id'];
    setTierName(tierId);

    if (currentTier.cost < 0) {
      setPriceText('-');
    }
    else if (currentTier.cost === 0) {
      setPriceText('Free');
    }
    else {
      setPriceText(`${currentTier.cost} $KDA`);
    }
    
    setTimerStatus(currentTier['status'])
    setEndTime(new Date(currentTier['end-time']['time']));
  }, [currentTier]);


  var timer
  const [countdown, setCountdown] = useState({});
  useEffect(() => {
    // console.log('tier has end', tierHasEnd);
    // console.log(timerStatus);
    if (timerStatus === 'final') {
      clearInterval(timer);
    }
    else {
      // If we already have a timer, clear it
      if (timer) {
        clearInterval(timer);
      }
      timer = setInterval(() => { 
        let countdownData = formatCountdown(endTime)
        setCountdown(countdownData);
        if (new Date() > endTime) {
          dispatch(setCurrentTier(getCurrentTier(collectionData.tiers)));
        }
      }, 1000);
    }
    
    return () => {
      clearInterval(timer);
    }
  }, [timerStatus, endTime, collectionData]);

  return (
    <FlexColumn className='gap-10'>
      {collectionStatus === 'complete' ?
        <h1 className='text-white text-7xl font-extrabold'>Collection Complete!</h1>
      :
        <FlexColumn className='gap-10'>
          <h1 className='text-7xl text-center'>{timerStatus === 'inactive' ? 'Sale Inactive' : tierName}</h1>
          {timerStatus !== 'final' && timerStatus !== 'inactive' ? 
            <FlexColumn className="flex-1 text-center">
              <p className='text-3xl'>{timerStatus === 'before' ? 'Mint Starts In' : 'Time Remaining'}</p>
              <FlexRow className='gap-4 justify-center'> 
                {countdown.days > 0 ? <FlexColumn className='w-32'>
                  <h1 className='flex-auto text-white text-7xl font-extrabold'>{countdown.days}</h1>
                  <p className='text-xl'>Days</p>
                </FlexColumn> : <></>}
                <FlexColumn className='w-32'>
                  <h1 className='flex-auto text-white text-7xl font-extrabold'>{countdown.hours}</h1>
                  <p className='text-xl'>Hours</p>
                </FlexColumn>
                <FlexColumn className='w-32'>
                  <h1 className='flex-auto text-white text-7xl font-extrabold'>{countdown.minutes}</h1>
                  <p className='text-xl'>Minutes</p>
                </FlexColumn>
                <FlexColumn className='w-32'>
                  <h1 className='flex-auto text-white text-7xl font-extrabold'>{countdown.seconds}</h1>
                  <p className='text-xl'>Seconds</p>
                </FlexColumn>
              </FlexRow>
            </FlexColumn> :
            <></>}
        </FlexColumn>
      }
      
      <FlexRow className="w-full gap-10 text-center">
        <FlexColumn className="flex-auto w-64 gap-4">
          <h1 className='text-white text-7xl font-extrabold'>{priceText}</h1>
          <p className='text-xl'>Current Price</p>
        </FlexColumn>
        <FlexColumn className="flex-auto w-64 gap-4">
          <h1 className='text-white text-7xl font-extrabold'>{minted} / {totalSupply}</h1>
          <p className='text-xl'>nfts Minted</p>
        </FlexColumn>
      </FlexRow>
    </FlexColumn>
  )
}

export default MintContractRender;
