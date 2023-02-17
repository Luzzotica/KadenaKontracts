

export const ZELCORE = 'ZELCORE';
const zelcore = {
  name: 'Zelcore',
  connect: async function(state) {
    try {
      window.open('zel:', '_self');
      const accounts = await fetch("http://127.0.0.1:9467/v1/accounts", {
        headers: {
            "Content-Type": "application/json",
        },
        method: "POST",
        body: JSON.stringify({ asset: "kadena" }),
      });
      
      const accountsJson = await accounts.json();

      return {
        status: 'success',
        message: '',
        account: {
          account: accountsJson.data[0],
          publicKey: accountsJson.data[1],
        }
      }
    }
    catch (e) {
      return {
        status: 'fail',
        message: e,
        account: {
          account: '',
          publicKey: '',
        }
      }
    }
  },
  disconnect: async function(state) {
    return {
      result: {
        status: 'success',
        message: '',
      }
    }
  },
  sign: async function(state, signingCommand) {
    // console.log('signing cmd', signingCommand);

    let code = signingCommand.pactCode;
    let data = signingCommand.envData;
    delete signingCommand.pactCode;
    delete signingCommand.envData;
    let cmd = {
      ...signingCommand,
      code: code,
      data: data,
    }

    window.open('zel:', '_self');
    let res = await fetch('http://127.0.0.1:9467/v1/sign', {
      headers: {
        "Content-Type": "application/json"
      },
      method: "POST",
      body: JSON.stringify(cmd)
    });

    if (res.ok) {
      const resJSON = await res.json();
      // console.log(resJSON);
      return resJSON.body;
    } else {
      const resTEXT = await res.text();
      return resTEXT;
    }
  }
}
export default zelcore;