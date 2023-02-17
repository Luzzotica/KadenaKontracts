import { toast } from "react-toastify";
import TitleMessageRender from "./TitleMessageRender";

export const walletConnectedToastManager = (provider) => {
  console.log(provider);
  if (provider && provider !== '') {
    toast.success('Wallet connected');
  }
}

export const messageToastManager = (message) => {
  if (message.type === 'error') {
    toast.error(message.data);
  }
  else {
    toast.success(message.data);
  }
}

export const txToastManager = async (txData) => {
  // console.log('txData');
  // console.log(txData);
  if (!txData || Object.keys(txData).length === 0) {
    return;
  }

  if ('listenPromise' in txData) {
    let id = toast.loading(<TitleMessageRender title={`Transaction Sent!`} message={`TX ID: ${txData.reqKey}`}/>, { type: toast.TYPE.INFO });
    let result = await txData.listenPromise;
    console.log(result);

    if (result.result.status === "success") {
      toast.update(id, { render: <TitleMessageRender title={`Success`} message={`${result.result.data}`}/>, type: toast.TYPE.SUCCESS, isLoading: false, autoClose: 5000 });
    }
    else {
      toast.update(id, { render: <TitleMessageRender title="Error" message={`${result.result.error.message}`}/>, type: toast.TYPE.ERROR, isLoading: false, autoClose: 5000 });
    }
  }
  else {
    if (txData.result.status === 'success') {
      toast.success(<TitleMessageRender title={`Success`} message={`${txData.result.data}`}/>);
    }
    else {
      toast.error(<TitleMessageRender title={`Error`} message={`${txData.result.error.message}`}/>)
    }
  }
}


