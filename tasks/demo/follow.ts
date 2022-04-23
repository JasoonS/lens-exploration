import { task } from 'hardhat/config';
import { LensHub__factory, FollowNFT__factory, SuperFollowModule__factory } from '../../typechain-types';
import { getAddrs, initEnv, waitForTx } from '../helpers/utils';

task('follow', 'follows a profile').setAction(async ({ }, hre) => {
  const [, , user, user2] = await initEnv(hre);
  const addrs = getAddrs();
  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], user);
  const profileId = await lensHub.getProfileIdByHandle('floatcapital');

  await waitForTx(lensHub.follow([profileId], [[]]));
  await waitForTx(lensHub.connect(user2).follow([profileId], [[]]));

  const followNFTAddr = await lensHub.getFollowNFT(profileId);
  const followModuleAddr = await lensHub.getFollowModule(profileId);
  console.log(
    `Follow Module for the "floatcapital" profile should be: ${followModuleAddr} (same as ${addrs["superFollow"]}`
  );
  const superFollowModule = await SuperFollowModule__factory.connect(followModuleAddr, user2);
  const followNFT = FollowNFT__factory.connect(followNFTAddr, user);

  const totalSupply = await followNFT.totalSupply();
  const ownerOf = await followNFT.ownerOf(1);
  const ownerOf2 = await followNFT.ownerOf(2);

  console.log(`Follow NFT total supply (should be 1): ${totalSupply}`);
  console.log(
    `Follow NFT owner of ID 1: ${ownerOf}, user address (should be the same): ${user.address}`
  );
  console.log(
    `Follow NFT owner of ID 2: ${ownerOf2}, user address (should be the same): ${user2.address}`
  );
});
