import { Button } from '@components/UI/Button'
import { Modal } from '@components/UI/Modal'
import { Profile } from '@generated/types'
import { StarIcon, FireIcon } from '@heroicons/react/outline'
import dynamic from 'next/dynamic'
import { Dispatch, FC, useState } from 'react'

import Loader from '../Loader'
import Slug from '../Slug'

const FollowModule = dynamic(() => import('./FollowModule'), {
  loading: () => <Loader message="Loading souper follow" />
})

interface Props {
  profile: Profile
  setFollowing: Dispatch<boolean>
  showText?: boolean
}

const SouperFollow: FC<Props> = ({
  profile,
  setFollowing,
  showText = false
}) => {
  const [showFollowModal, setShowFollowModal] = useState<boolean>(false)

  return (
    <>
      <Button
        className="text-sm !px-3 !py-1.5 my-1"
        variant="gold"
        outline
        onClick={() => setShowFollowModal(!showFollowModal)}
        icon={<FireIcon className="w-4 h-4" />}
      >
        {showText && `Golden circle 12/100`}
      </Button>
      <Modal
        title={
          <div className="flex flex-row">
            Join{`  `}
            <Slug slug={profile?.handle} prefix="@" />
            {"'s "} golden circle{' '}
            <img
              className="w-6 h-6"
              src={'https://assets.lenster.xyz/images/tokens/wmatic.svg'}
            />
          </div>
        }
        icon={<FireIcon className="w-5 h-5 text-amber-500" />}
        show={showFollowModal}
        onClose={() => setShowFollowModal(!showFollowModal)}
      >
        <FollowModule
          profile={profile}
          setFollowing={setFollowing}
          setShowFollowModal={setShowFollowModal}
        />
      </Modal>
    </>
  )
}

export default SouperFollow
