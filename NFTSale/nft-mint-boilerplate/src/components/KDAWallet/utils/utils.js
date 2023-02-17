import { send, listen } from '@kadena/chainweb-node-client';
import { hash } from '@kadena/cryptography-utils';
// import Pact from 'pact-lang-api';

export const creationTime = () => String(Math.round(new Date().getTime() / 1000) - 10);

export const buildUrl = (network, networkId, chainId) => {
  return `${network}/chainweb/0.0/${networkId}/chain/${chainId}/pact`;
}

export const createPactCommand = (getState, chainId, pactCode, envData={}, gasLimit=15000, gasPrice=1e-5, includeSigner=false, caps=[]) => {
  let kadenaSliceState = getState().kadenaInfo;
  let signers = [];

  if (includeSigner) {
    let signer = {
      pubKey: kadenaInfo.pubKey
    };
    if (caps.length > 0) {
      signer.caps = caps;
    }
    signers.push(signer);
  }

  let cmd = {
    networkId: kadenaSliceState.networkId,
    payload: {
      exec: {
        data: envData,
        code: pactCode,
      }
    },
    signers: [], // [signer]
    meta: {
      chainId: chainId,
      gasLimit: gasLimit,
      gasPrice: gasPrice,
      sender: kadenaSliceState.account,
      ttl: kadenaSliceState.ttl,
      creationTime: creationTime(),
    },
    nonce: Date.now().toString(),
  };
  let cmdString = JSON.stringify(cmd);
  let h = hash(cmdString);
  // let signer = {
  //   pubKey: kadenaSliceState.pubKey
  // }
  // if (caps.length > 0) {
  //   signer['caps'] = caps;
  // }

  return {
    cmd: cmdString,
    hash: h,
    sigs: [],
  }
}

export const createSigningCommand = (getState, chainId, pactCode, envData, caps=[], gasLimit=15000, gasPrice=1e-5) => {
  let kadenaSliceState = getState().kadenaInfo;
  return {
    pactCode: pactCode,
    envData: envData,
    sender: kadenaSliceState.account,
    networkId: kadenaSliceState.networkId,
    chainId: chainId,
    gasLimit: gasLimit,
    gasPrice: gasPrice,
    signingPubKey: kadenaSliceState.pubKey,
    ttl: kadenaSliceState.ttl,
    caps: caps,
  }
}

export const createCap = (role, description, name, args) => {
  return {
    role: role,
    description: description,
    cap: {
      name: name,
      args: args,
    }
  }
  // return Pact.lang.mkCap(role, description, name, args);
}

export const sendCommand = async function(getState, chainId, signedCmd) {
  let kadenaInfo = getState().kadenaInfo;
  let networkUrl = buildUrl(kadenaInfo.network, kadenaInfo.networkId, chainId);

  let res = await fetch(`${networkUrl}/api/v1/send`, {
    headers: {
      "Content-Type": "application/json"
    },
    method: "POST",
    body: JSON.stringify({ cmds: [signedCmd] })
  });

  let data = parseRes(res)
  return data;
}

export const localCommand = async function (getState, chainId, cmd) {
  let kadenaInfo = getState().kadenaInfo;
  let networkUrl = buildUrl(kadenaInfo.network, kadenaInfo.networkId, chainId);

  let res = await fetch(`${networkUrl}/api/v1/local`, {
    headers: {
      "Content-Type": "application/json"
    },
    method: "POST",
    body: JSON.stringify(cmd)
  });

  let data = parseRes(res);
  return data;
}

export const listenTx = async function (getState, chainId, txId) {
  let kadenaInfo = getState().kadenaInfo;
  let networkUrl = buildUrl(kadenaInfo.network, kadenaInfo.networkId, chainId);
  return await listen({ listen: txId }, networkUrl);
  // return await Pact.fetch.listen({ listen: txId }, networkUrl);
}

export const mkReq = function (cmd) {
  return {
    headers: {
      'Content-Type': 'application/json',
    },
    method: 'POST',
    body: JSON.stringify(cmd),
  };
};

export const parseRes = async function (raw) {
  const rawRes = await raw;
  const res = await rawRes;
  if (res.ok) {
    const resJSON = await rawRes.json();
    return resJSON;
  } else {
    const resTEXT = await rawRes.text();
    return resTEXT;
  }
};

export const wait = async (timeout) => {
  return new Promise((resolve) => {
    setTimeout(resolve, timeout);
  });
};

export const handleError = (error) => {
  console.log(`ERROR: ${JSON.stringify(error)}`);
  return { errorMessage: 'Unhandled Exception' };
};

Date.prototype.yyyymmdd = function() {
  var mm = this.getMonth() + 1; // getMonth() is zero-based
  var dd = this.getDate();

  return [this.getFullYear(),
          (mm>9 ? '' : '0') + mm,
          (dd>9 ? '' : '0') + dd
         ].join('');
};

Date.prototype.yyyy_mm_dd = function() {
  var mm = this.getMonth() + 1; // getMonth() is zero-based
  var dd = this.getDate();

  return [this.getFullYear(),
          (mm>9 ? '' : '0') + mm,
          (dd>9 ? '' : '0') + dd
         ].join('-');
};
