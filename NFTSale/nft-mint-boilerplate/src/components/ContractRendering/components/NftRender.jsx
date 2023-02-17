import { useEffect, useState } from "react";
import { CollectionShape } from "../../../assets";
import FlexColumn from "../../Layout/FlexColumn";
import FlexRow from "../../Layout/FlexRow";
import { RARITIES } from "../utils/constants";

function NftRender(props) {
  const { nft, uri, metadataUri } = props;
  console.log(uri);
  
  const [metadata, setMetadata] = useState({});

  const fetchMetadata = async () => {
    const response = await fetch(metadataUri);
    const data = await response.json();
    setMetadata(data);
  }

  useEffect(() => {
    fetchMetadata();
  }, []);

  // Unpack the metadata, get the attributes, and create a list with it
  const [attributes, setAttributes] = useState([]);
  useEffect(() => {
    if (metadata.attributes) {
      let attribute_traits = Object.keys(metadata.attributes);
      var l = [];
      for (var i = 0; i < attribute_traits.length; i++) {
        let trait = attribute_traits[i];
        let value = metadata.attributes[trait];
        l.push(<li key={`attr-${i}`}>
          {trait}: {value} ({RARITIES[trait][value]}%)
        </li>);
      }
      setAttributes(l);
    }
  }, [metadata]);


  // If reservation, show the super bod
  if (!nft.revealed) {
    return (
      <div className='relative group w-64 h-64'>
        <CollectionShape width='100%' height='100%'/>
        <FlexColumn className='absolute inset-0 h-auto w-64 text-white justify-center'>
          <h1 className="font-bold text-3xl text-center">Minting and Revealing</h1>
        </FlexColumn>
      </div>
    )
  }
  else { // Otherwise, use the bod and uri to load in the actual bod
    // console.log('dadbod render uri', uri); // <a href={`${uri}.png`}>
    return (
      <FlexRow className='gap-4 w-max h-64 rounded-3xl overflow-clip bg-opacity-50 bg-black'>
        <img
          className="w-64 h-64 rounded-3xl overflow-clip"
          src={`${uri}`}
        />
        <FlexColumn className='flex-1 w-64 pr-2 text-white justify-center'>
          <h1 className="font-bold text-xl text-center">{metadata.name}</h1>
          <ul className=" text-sm">
            {attributes}
          </ul>
        </FlexColumn>
      </FlexRow>
      // <div className='relative group w-64 h-64'>
      //   <CollectionShape className='w-64 h-64' width='70%' height='100%'/>
      //   <FlexColumn className='absolute inset-0 text-white justify-center rounded-3xl overflow-clip'>
          
      //   </FlexColumn>
      // </div>
      
    )
  }

  return (
    <FlexColumn className='flex-1'>
        
    </FlexColumn>
  )
}

export default NftRender
