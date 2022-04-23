import '@nomiclabs/hardhat-ethers';
import { hexlify, hexZeroPad } from 'ethers/lib/utils';
import { task } from 'hardhat/config';
import { LensHub__factory, SuperFollowModule__factory } from '../../typechain-types';
import { CreateProfileDataStruct } from '../../typechain-types/LensHub';
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS } from '../helpers/utils';

task('create-profile', 'creates a profile').setAction(async ({ }, hre) => {
  const [governance, , user] = await initEnv(hre);
  const addrs = getAddrs();
  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);
  const superFollowModuleAddr = addrs['superFollow'];
  const superFollowModule = SuperFollowModule__factory.connect(superFollowModuleAddr, governance);

  const followModuleInitData = await superFollowModule.hackToEncodeValueAsBytes(1, "100000000000");

  await waitForTx(lensHub.whitelistProfileCreator(user.address, true));

  const inputStruct: CreateProfileDataStruct = {
    to: user.address,
    handle: 'floatcapital',
    imageURI:
      'https://ipfs.fleek.co/ipfs/QmY2tMCbnrsZCuTWceHtWDf8C2frAg9MUPep9WQJwhEfFP',
    followModule: superFollowModuleAddr,
    followModuleInitData: followModuleInitData,
    followNFTURI:
      'https://ipfs.fleek.co/ipfs/QmY2tMCbnrsZCuTWceHtWDf8C2frAg9MUPep9WQJwhEfFP',
  };

  await waitForTx(lensHub.connect(user).createProfile(inputStruct));

  console.log(`Total supply (should be 1): ${await lensHub.totalSupply()}`);
  const profileId = await lensHub.getProfileIdByHandle('floatcapital');
  console.log(
    `Profile owner: ${await lensHub.ownerOf(profileId)}, user address (should be the same): ${user.address}`
  );
  console.log(`Profile ID by handle: ${profileId}`);
});
