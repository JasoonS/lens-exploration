import LensHubProxy from '@abis/LensHubProxy.json'
import SuperFollowModuleAbi from '@abis/SuperFollowModule.json'
import CurrencyAbi from '@abis/Currency.json'
import { gql, useMutation, useQuery } from '@apollo/client'
import { ALLOWANCE_SETTINGS_QUERY } from '@components/Settings/Allowance'
import AllowanceButton from '@components/Settings/Allowance/Button'
import { Button } from '@components/UI/Button'
import { Spinner } from '@components/UI/Spinner'
import AppContext from '@components/utils/AppContext'
import { Input } from '@components/UI/Input'
import {
  CreateFollowBroadcastItemResult,
  FeeFollowModuleSettings,
  Profile
} from '@generated/types'
import { StarIcon, UserIcon, FireIcon } from '@heroicons/react/outline'
import consoleLog from '@lib/consoleLog'
import formatAddress from '@lib/formatAddress'
import getTokenImage from '@lib/getTokenImage'
import omit from '@lib/omit'
import splitSignature from '@lib/splitSignature'
import trackEvent from '@lib/trackEvent'
import { Dispatch, FC, useContext, useState, useEffect } from 'react'
import toast from 'react-hot-toast'
import { Form, useZodForm } from '@components/UI/Form'
import { CalculateHarbergerTaxDepositDuration } from '@components/utils/time'
import { object, string } from 'zod'
import {
  CHAIN_ID,
  CONNECT_WALLET,
  ERROR_MESSAGE,
  LENSHUB_PROXY,
  POLYGONSCAN_URL,
  WRONG_NETWORK
} from 'src/constants'
import {
  useAccount,
  useContractWrite,
  useNetwork,
  useSignTypedData
} from 'wagmi'
import dayjs from 'dayjs'
import duration from 'dayjs/plugin/duration'

import Loader from '../Loader'
import Slug from '../Slug'

dayjs.extend(duration)

const SUPER_FOLLOW_QUERY = gql`
  query SuperFollow($request: ProfileQueryRequest!) {
    profiles(request: $request) {
      items {
        id
        followModule {
          ... on FeeFollowModuleSettings {
            amount {
              asset {
                name
                symbol
                address
              }
              value
            }
            recipient
          }
        }
      }
    }
  }
`

const CREATE_FOLLOW_TYPED_DATA_MUTATION = gql`
  mutation CreateFollowTypedData($request: FollowRequest!) {
    createFollowTypedData(request: $request) {
      id
      expiresAt
      typedData {
        domain {
          name
          chainId
          version
          verifyingContract
        }
        types {
          FollowWithSig {
            name
            type
          }
        }
        value {
          nonce
          deadline
          profileIds
          datas
        }
      }
    }
  }
`

interface GoldenCircleButtonProps {
  // setApproved: Dispatch<boolean>
}

const GoldenCircleButton: FC<GoldenCircleButtonProps> = ({}) => {
  const { activeChain } = useNetwork()
  const { data: account } = useAccount()

  //todo args
  /*
      uint256 profileId,
        uint256 oldFollowNFTTokenId,
        uint256 newFollowNFTTokenId,
        uint256 _newPrice,
        uint256 previousPrice,
        uint256 depositAmount
  */
  let tokenIdSame = '1'
  let profileId = '1'
  let oldFollowNFTTokenId = tokenIdSame
  let newFollowNFTTokenId = tokenIdSame
  let newPrice = '100'
  let previousPrice = '0'
  let depositAmount = '1000000000000000'
  const { isLoading: writeLoading, write } = useContractWrite(
    {
      addressOrName: '0xDe97f683aB64aAFBbb060F1822b6A8feB8140D1C',
      contractInterface: SuperFollowModuleAbi
    },
    'upgradeToSuperFollower',
    {
      args: [
        profileId,
        oldFollowNFTTokenId,
        newFollowNFTTokenId,
        newPrice,
        previousPrice,
        depositAmount
      ],
      onSuccess() {
        // setJoinedGoldenCircle(true)
        toast.success('Joined golden circle successfully!')
        trackEvent('Joined golden circle')
      },
      onError(error) {
        toast.error(error?.message)
      }
    }
  )

  // Hackathon todo: Cater to our follow module
  const createGoldenCircleFollow = () => {
    if (!account?.address) {
      toast.error(CONNECT_WALLET)
    } else if (activeChain?.id !== CHAIN_ID) {
      toast.error(WRONG_NETWORK)
    } else {
      write()
      console.log('call the contract function')
    }
  }

  return (
    <Button
      className="text-sm !px-3 !py-1.5 "
      variant="gold"
      outline
      onClick={createGoldenCircleFollow}
      disabled={writeLoading}
      icon={
        writeLoading ? (
          <Spinner variant="super" size="xs" />
        ) : (
          <FireIcon className="w-4 h-4" />
        )
      }
    >
      Join the golden circle
    </Button>
  )
}

interface CustomApproveProps {
  setApproved: Dispatch<boolean>
}

const CustomApproveButton: FC<CustomApproveProps> = ({ setApproved }) => {
  const { activeChain } = useNetwork()
  const { data: account } = useAccount()

  let spender = '0xDe97f683aB64aAFBbb060F1822b6A8feB8140D1C' // hackathon TODO: be careful of possible redeployment
  let amount = '999999999999999999999999'

  const { isLoading: writeLoading, write } = useContractWrite(
    {
      addressOrName: '0x06577b0b09e69148a45b866a0de6643b6cac40af',
      contractInterface: CurrencyAbi
    },
    'approve',
    {
      args: [spender, amount],
      onSuccess() {
        setApproved(true)
        toast.success('Successfully approved contract')
        trackEvent('Successfully approved contract')
      },
      onError(error) {
        toast.error(error?.message)
      }
    }
  )

  const approveContractSpend = () => {
    if (!account?.address) {
      toast.error(CONNECT_WALLET)
    } else if (activeChain?.id !== CHAIN_ID) {
      toast.error(WRONG_NETWORK)
    } else {
      write()
      console.log('call the contract function')
    }
  }

  return (
    <Button
      className="text-sm !px-3 !py-1.5 "
      variant="primary"
      outline
      onClick={approveContractSpend}
    >
      Approve Golden Circle contract
    </Button>
  )
}

interface Props {
  profile: Profile
  setFollowing: Dispatch<boolean>
  setShowFollowModal: Dispatch<boolean>
}

const FollowModule: FC<Props> = ({
  profile,
  setFollowing,
  setShowFollowModal
}) => {
  const { currentUser } = useContext(AppContext)
  const [allowed, setAllowed] = useState<boolean>(true)
  const [approved, setApproved] = useState<boolean>(false)
  const { activeChain } = useNetwork()
  const { data: account } = useAccount()
  const { isLoading: signLoading, signTypedDataAsync } = useSignTypedData({
    onError(error) {
      toast.error(error?.message)
    }
  })
  const { isLoading: writeLoading, write } = useContractWrite(
    {
      addressOrName: LENSHUB_PROXY, // TODO:
      contractInterface: LensHubProxy
    },
    'followWithSig',
    {
      onSuccess() {
        setFollowing(true)
        setShowFollowModal(false)
        toast.success('Followed successfully!')
        trackEvent('super follow user')
      },
      onError(error) {
        toast.error(error?.message)
      }
    }
  )

  const { data, loading } = useQuery(SUPER_FOLLOW_QUERY, {
    variables: { request: { profileIds: profile?.id } },
    skip: !profile?.id,
    onCompleted() {
      consoleLog(
        'Query',
        '#8b5cf6',
        `Fetched super follow details Profile:${profile?.id}`
      )
    }
  })

  const followModule: FeeFollowModuleSettings =
    data?.profiles?.items[0]?.followModule

  const [createFollowTypedData, { loading: typedDataLoading }] = useMutation(
    CREATE_FOLLOW_TYPED_DATA_MUTATION,
    {
      onCompleted({
        createFollowTypedData
      }: {
        createFollowTypedData: CreateFollowBroadcastItemResult
      }) {
        consoleLog('Mutation', '#4ade80', 'Generated createFollowTypedData')
        const { typedData } = createFollowTypedData
        signTypedDataAsync({
          domain: omit(typedData?.domain, '__typename'),
          types: omit(typedData?.types, '__typename'),
          value: omit(typedData?.value, '__typename')
        }).then((signature) => {
          const { profileIds, datas: followData } = typedData?.value
          const { v, r, s } = splitSignature(signature)
          const inputStruct = {
            follower: account?.address,
            profileIds,
            datas: followData,
            sig: {
              v,
              r,
              s,
              deadline: typedData.value.deadline
            }
          }
          write({ args: inputStruct })
        })
      },
      onError(error) {
        toast.error(error.message ?? ERROR_MESSAGE)
      }
    }
  )

  const createFollow = () => {
    if (!account?.address) {
      toast.error(CONNECT_WALLET)
    } else if (activeChain?.id !== CHAIN_ID) {
      toast.error(WRONG_NETWORK)
    } else {
      createFollowTypedData({
        variables: {
          request: {
            follow: {
              profile: profile?.id,
              followModule: {
                feeFollowModule: {
                  amount: {
                    currency: followModule?.amount?.asset?.address,
                    value: followModule?.amount?.value
                  }
                }
              }
            }
          }
        }
      })
    }
  }

  const harbergerDataSchema = object({
    salePrice: string()
      .min(1, { message: 'Invalid value' })
      .max(10000000, { message: 'Invalid value' }),
    deposit: string()
      .min(1, { message: 'Invalid value' })
      .max(10000000, { message: 'Invalid value' })
  })

  const form = useZodForm({
    schema: harbergerDataSchema,
    defaultValues: {
      salePrice: 1200,
      deposit: 120
    }
  })

  const numberOfGoldenCircleNfts = 10 // hackathon TODO: pull from contracts

  let [salePriceState, setSalePriceState] = useState(1200)
  let [depositState, setDepositState] = useState(120)

  let updateValues = () => {
    let { salePrice, deposit } = form.getValues()
    setDepositState(deposit)
    setSalePriceState(salePrice)
  }

  if (loading) return <Loader message="Loading super follow" />

  return (
    <div className="p-5">
      <div className="pb-2 space-y-1.5">
        <div className="font-bold">
          Golden circle NFT holders get exclusive rights to collect{' '}
          <Slug slug={profile?.handle} prefix="@" />
          &rsquo;s publications
        </div>
        <div className="text-gray-400 text-xs">
          {profile?.handle} has {numberOfGoldenCircleNfts} golden circle NFTs.
          Golden circle NFTs are always on sale. This means when you purchase a
          golden circle nft you are instantly required to set a sale price. You
          pay 10% of your sale price each month to remain the owner of the
          golden circle NFT.
        </div>
      </div>

      <hr className="mt-4" />
      <div className="flex items-center py-2 space-x-1.5">
        <Form
          form={form}
          className="space-y-4 flex flex-row w-full"
          onSubmit={({}) => {}}
        >
          <div className="flex flex-row w-full">
            <div className="w-full">
              <Input
                label="New sale price"
                helper={
                  <span>
                    Set the new sale price, this is required to be set, you pay
                    a monthly pledge of 10% of this amount. If someone purchases
                    the golden circle NFT from you, you will receive this
                    payment
                  </span>
                }
                type="number"
                placeholder={salePriceState} // hackathon TODO: set this to prevSale price * 1.1
                min="0"
                max="10000000000000"
                onClick={() => updateValues()} // Spending to much time on this form lib to capture a change event
                // onBlur={() => console.log('test2')}
                // onChange={() => console.log('test3')}
                {...form.register('salePrice')}
              />
            </div>

            <div className="w-full pl-2">
              <Input
                label="Deposit to fund pledge"
                helper={
                  <span>
                    Deposit funds into the contract that can be used to stream
                    funds to for the monthly pledge
                  </span>
                }
                type="number"
                placeholder={depositState}
                min="1"
                max="10000000000000"
                {...form.register('deposit')}
              />
            </div>
          </div>
          <p className="text-xs">
            Your pledge of {salePriceState / 12} tokens per month will last ±{' '}
            {dayjs
              .duration({
                seconds:
                  CalculateHarbergerTaxDepositDuration(
                    salePriceState,
                    0.1,
                    depositState
                  ) / 10
              })
              .humanize()}
          </p>
        </Form>
      </div>

      <div className="flex items-center space-x-2">
        <UserIcon className="w-3 h-3 text-gray-500" />
        <div className="space-x-1.5 text-xs">
          <span>Recipient:</span>
          <a
            href={`${POLYGONSCAN_URL}/address/${followModule?.recipient}`}
            target="_blank"
            className="font-bold text-gray-600 "
            rel="noreferrer noopener"
          >
            {formatAddress(followModule?.recipient)}
          </a>
        </div>
      </div>
      {currentUser ? (
        <div className="flex flex-row mt-5">
          {!approved ? (
            <div className="mr-5">
              <CustomApproveButton setApproved={setApproved} />
            </div>
          ) : null}
          <GoldenCircleButton />
        </div>
      ) : null}
    </div>
  )
}

export default FollowModule
