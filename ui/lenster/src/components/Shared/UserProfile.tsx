import { Profile } from '@generated/types'
import { BadgeCheckIcon } from '@heroicons/react/solid'
import getAvatar from '@lib/getAvatar'
import isVerified from '@lib/isVerified'
import clsx from 'clsx'
import Link from 'next/link'
import React, { FC, useState } from 'react'

import Follow from './Follow'
import GoldenCircleFollow from './GoldenCircleFollow'
import Slug from './Slug'
import SuperFollow from './SuperFollow'
import SouperFollow from './SouperFollow'
import Unfollow from './Unfollow'

interface Props {
  profile: Profile
  showBio?: boolean
  showFollow?: boolean
  followStatusLoading?: boolean
  isFollowing?: boolean
  isBig?: boolean
}

const UserProfile: FC<Props> = ({
  profile,
  showBio = false,
  showFollow = false,
  followStatusLoading = false,
  isFollowing = false,
  isBig = false
}) => {
  const [following, setFollowing] = useState<boolean>(isFollowing)

  return (
    <div className="flex justify-between items-center">
      <Link href={`/u/${profile?.handle}`}>
        <a href={`/u/${profile?.handle}`}>
          <div className="flex items-center space-x-3">
            <img
              src={getAvatar(profile)}
              className={clsx(
                isBig ? 'w-14 h-14' : 'w-10 h-10',
                'bg-gray-200 rounded-full border dark:border-gray-700/80'
              )}
              alt={profile?.handle}
            />
            <div>
              <div className="flex gap-1 items-center">
                <div className={clsx(isBig ? 'font-bold' : 'text-md')}>
                  {profile?.name ?? profile?.handle}
                </div>
                {isVerified(profile?.id) && (
                  <BadgeCheckIcon className="w-4 h-4 text-brand" />
                )}
              </div>
              <Slug className="text-sm" slug={profile?.handle} prefix="@" />
              {showBio && profile?.bio && (
                <div className={clsx(isBig ? 'text-md' : 'text-sm', 'mt-2')}>
                  {profile?.bio}
                </div>
              )}
            </div>
          </div>
        </a>
      </Link>
      {showFollow &&
        (followStatusLoading ? (
          <div className="w-10 h-8 rounded-lg shimmer" />
        ) : following ? (
          <Unfollow profile={profile} setFollowing={setFollowing} />
        ) : profile?.followModule ? (
          <div>
            <SuperFollow profile={profile} setFollowing={setFollowing} />
            <SouperFollow profile={profile} setFollowing={setFollowing} />
          </div>
        ) : (
          <div>
            <Follow profile={profile} setFollowing={setFollowing} />
            <GoldenCircleFollow profile={profile} setFollowing={setFollowing} />
            <SouperFollow profile={profile} setFollowing={setFollowing} />
          </div>
        ))}
    </div>
  )
}

export default UserProfile
