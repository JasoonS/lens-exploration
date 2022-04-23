import { task } from 'hardhat/config';
import { LensHub__factory, FollowNFT__factory, SuperFollowModule__factory, Currency__factory } from '../../typechain-types';
import { getAddrs, initEnv, waitForTx, ZERO_ADDRESS } from '../helpers/utils';

task('follow-mumbai', 'follows a profile').setAction(async ({ }, hre) => {
  const [, , user, user2] = await initEnv(hre);
  const addrs = getAddrs();
  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], user);
  const profileId = await lensHub.getProfileIdByHandle('floatcapital');
  console.log("user address:", user.address, user2.address);

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

  //   const currencyAddress = addrs.currency;
  //   const currency = Currency__factory.connect(currencyAddress, user2);
  //   const thousandUnits = "1000000000000000000000" /* 1000 units */;
  //   const twentyUnits = "20000000000000000000" /* 1000 units */;
  //   const thirtyUnits = "30000000000000000000" /* 1000 units */;
  //   await currency.mint(user.address, thousandUnits);
  //   await currency.mint(user2.address, thousandUnits);

  //   await currency.increaseAllowance(superFollowModule.address, thousandUnits)
  //   await currency.connect(user).increaseAllowance(superFollowModule.address, thousandUnits)

  //   let isSuperFollowingUser1;
  //   let isSuperFollowingUser2;
  //   isSuperFollowingUser1 = await superFollowModule.isSuperFollower(profileId, ZERO_ADDRESS /*unused argument*/, 1);
  //   isSuperFollowingUser2 = await superFollowModule.isSuperFollower(profileId, ZERO_ADDRESS /*unused argument*/, 2);
  //   console.log(`User 1 is a super follower: ${isSuperFollowingUser1}
  // User 2 is a super follower: ${isSuperFollowingUser2}`);
  //   console.log("User 2 becomes super follower")

  //   await superFollowModule.connect(user2).upgradeToSuperFollower(profileId, 2, 2, twentyUnits, 0, twentyUnits);
  //   isSuperFollowingUser1 = await superFollowModule.isSuperFollower(profileId, ZERO_ADDRESS /*unused argument*/, 1);
  //   isSuperFollowingUser2 = await superFollowModule.isSuperFollower(profileId, ZERO_ADDRESS /*unused argument*/, 2);
  //   console.log(`User 1 is a super follower: ${isSuperFollowingUser1}
  //   User 2 is a super follower: ${isSuperFollowingUser2}`);

  //   console.log("User 1 takes super follower token from user1")
  //   await superFollowModule.connect(user).upgradeToSuperFollower(profileId, 2, 1, thirtyUnits, twentyUnits, twentyUnits);
  //   isSuperFollowingUser1 = await superFollowModule.isSuperFollower(profileId, ZERO_ADDRESS /*unused argument*/, 1);
  //   isSuperFollowingUser2 = await superFollowModule.isSuperFollower(profileId, ZERO_ADDRESS /*unused argument*/, 2);
  //   console.log(`User 1 is a super follower: ${isSuperFollowingUser1}
  //   User 2 is a super follower: ${isSuperFollowingUser2}`);
});
