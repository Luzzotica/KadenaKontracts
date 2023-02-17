import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import FlexColumn from '../../Layout/FlexColumn';
import FlexRow from '../../Layout/FlexRow';
import NftRender from './NftRender';

function NftList(props) {
  const uriRoot = useSelector(state => state.mintInfo.uriRoot);
  const userNfts = useSelector(state => state.mintInfo.nfts);

  const [nftRenders, setNftRenders] = useState([]);

  useEffect(() => {
    var l = [];
    for (var i = 0; i < userNfts.length; i++) {
      console.log(userNfts[i]);
      l.push(<NftRender
        key={`nft-${userNfts[i]['token-id']['int']}`} 
        nft={userNfts[i]} 
        uri={`${uriRoot}${userNfts[i]['token-id']['int']}.gif`}
        metadataUri={`${uriRoot}${userNfts[i]['token-id']['int']}.json`}/>);
    }

    setNftRenders(l);
    
  }, [uriRoot, userNfts]);

  if (nftRenders.length > 0) {
    return (
      <FlexColumn className={`gap-2 px-4 text-white place-items-center ${props.className}`}>
        <span className='text-7xl font-bold text-center'>Your nfts</span>
        <div className='w-full grid grid-flow-row grid-cols-1 xl:grid-cols-2 gap-4 place-items-center'>
          {nftRenders}
        </div>
        {/* <FlexRow className='w-full flex-1 gap-2 justify-around place-items-center '>
          {nftRenders}
        </FlexRow> */}
      </FlexColumn>
    );
  }
  else {
    return (
      <FlexColumn className={`gap-2 px-4 text-white place-items-center ${props.className}`}>
        <span className='text-4xl font-bold text-center'>You don't own any nfts! Mint one! They will show up here!</span>
      </FlexColumn>
    );
  }
}

export default NftList
