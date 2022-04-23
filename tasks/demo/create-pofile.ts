import '@nomiclabs/hardhat-ethers';
import { hexlify, hexZeroPad } from 'ethers/lib/utils';
import { task } from 'hardhat/config';
import { LensHub__factory, SuperFollowModule__factory } from '../../typechain-types';
import { CreateProfileDataStruct } from '../../typechain-types/LensHub';
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS } from '../helpers/utils';

task('create-profile', 'creates a profile').setAction(async ({ }, hre) => {
  const [governance, profileOwner] = await initEnv(hre);
  const addrs = getAddrs();
  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);
  const superFollowModuleAddr = addrs['superFollow'];
  const currencyAddress = addrs.currency;
  const superFollowModule = SuperFollowModule__factory.connect(superFollowModuleAddr, governance);

  const followModuleInitData = await superFollowModule.hackToEncodeValueAsBytes(1, "100000000000", currencyAddress);

  await waitForTx(lensHub.whitelistProfileCreator(profileOwner.address, true));

  const inputStruct: CreateProfileDataStruct = {
    to: profileOwner.address,
    handle: 'floatcapital',
    imageURI:
      'https://ipfs.fleek.co/ipfs/Qmc7xwadkq4XaSuwYz1CHeJgqiHdmcU3LqzQ5XshsC6LG1',
    followModule: superFollowModuleAddr,
    followModuleInitData: followModuleInitData,
    followNFTURI:
      'https://ipfs.fleek.co/ipfs/Qmdcv5bUcg4v3r2NWcRpnExpDbE3yXfzxXUub9ESZsJRJp',
  };

  await waitForTx(lensHub.connect(profileOwner).createProfile(inputStruct));

  console.log(`Total supply (should be 1): ${await lensHub.totalSupply()}`);
  const profileId = await lensHub.getProfileIdByHandle('floatcapital');
  console.log(
    `Profile owner: ${await lensHub.ownerOf(profileId)}, user address (should be the same): ${profileOwner.address}`
  );
  console.log(`Profile ID by handle: ${profileId}`);
});
