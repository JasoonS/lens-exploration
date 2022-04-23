import { task } from 'hardhat/config';
import { LensHub__factory } from '../../typechain-types';
import { PostDataStruct } from '../../typechain-types/LensHub';
import { getAddrs, initEnv, waitForTx, ZERO_ADDRESS } from '../helpers/utils';

task('post', 'publishes a post').setAction(async ({ }, hre) => {
  const [governance, , user] = await initEnv(hre);
  const addrs = getAddrs();

  //// NOTE: we are using this "fee collect module" because the "empty collect module" is undefined
  const emptyCollectModuleAddr = addrs['fee collect module'];

  // const emptyCollectModuleAddr = addrs['empty collect module'];
  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);
  console.log(0, emptyCollectModuleAddr, addrs)
  await waitForTx(lensHub.whitelistCollectModule(emptyCollectModuleAddr, true));
  console.log(1)

  const inputStruct: PostDataStruct = {
    profileId: 1,
    contentURI:
      'https://ipfs.fleek.co/ipfs/plantghostplantghostplantghostplantghostplantghostplantghos',
    collectModule: emptyCollectModuleAddr,
    collectModuleInitData: [],
    referenceModule: ZERO_ADDRESS,
    referenceModuleInitData: [],
  };

  console.log(2)
  await waitForTx(lensHub.connect(user).post(inputStruct));
  console.log(3)
  console.log(await lensHub.getPub(1, 1));
});
