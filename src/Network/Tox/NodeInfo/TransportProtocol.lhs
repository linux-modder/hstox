\section{Transport Protocol}

A Transport Protocol is a transport layer protocol directly below the Tox
protocol itself.  Tox supports two transport protocols: UDP and TCP.  The
binary representation of the Transport Protocol is a single bit: 0 for UDP, 1
for TCP.  If encoded as standalone value, the bit is stored in the least
significant bit of a byte.  If followed by other bit-packed data, it consumes
exactly one bit.

The human-readable representation for UDP is \texttt{UDP} and for TCP is
\texttt{TCP}.

\begin{code}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase    #-}
{-# LANGUAGE Trustworthy   #-}
module Network.Tox.NodeInfo.TransportProtocol where

import           Data.Aeson                (FromJSON, ToJSON)
import           Data.Binary               (Binary)
import qualified Data.Binary.Bits.Get      as Bits (getBool)
import qualified Data.Binary.Bits.Put      as Bits (putBool)
import           GHC.Generics              (Generic)
import           Network.Tox.Encoding      (BitEncoding, bitGet, bitPut)
import           Network.Tox.RPC           (MessagePack)
import           Test.QuickCheck.Arbitrary (Arbitrary, arbitrary)


{-------------------------------------------------------------------------------
 -
 - :: Implementation.
 -
 ------------------------------------------------------------------------------}


data TransportProtocol
  = UDP
  | TCP
  deriving (Eq, Show, Read, Generic)

instance Binary TransportProtocol
instance ToJSON TransportProtocol
instance FromJSON TransportProtocol
instance MessagePack TransportProtocol

instance BitEncoding TransportProtocol where
  bitGet = fmap (\case
      False -> UDP
      True  -> TCP
    ) Bits.getBool

  bitPut UDP = Bits.putBool False
  bitPut TCP = Bits.putBool True


{-------------------------------------------------------------------------------
 -
 - :: Tests.
 -
 ------------------------------------------------------------------------------}


instance Arbitrary TransportProtocol where
  arbitrary =
    fmap (\case
        False -> UDP
        True  -> TCP)
      arbitrary
\end{code}
