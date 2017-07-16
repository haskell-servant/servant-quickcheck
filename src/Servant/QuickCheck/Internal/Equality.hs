module Servant.QuickCheck.Internal.Equality where

import Data.Aeson          (Value, decode, decodeStrict)
import Data.ByteString     (ByteString)
import qualified Data.ByteString.Lazy as LB
import Data.Function       (on)
import Network.HTTP.Client (Response, responseBody)
import Prelude.Compat

newtype ResponseEquality b
  = ResponseEquality { getResponseEquality :: Response b -> Response b -> Bool }

instance Monoid (ResponseEquality b) where
  mempty = ResponseEquality $ \_ _ -> True
  ResponseEquality a `mappend` ResponseEquality b = ResponseEquality $ \x y ->
    a x y && b x y

-- | Use `Eq` instance for `Response`
--
-- /Since 0.0.0.0/
allEquality :: Eq b => ResponseEquality b
allEquality = ResponseEquality (==)

-- | ByteString `Eq` instance over the response body.
--
-- /Since 0.0.0.0/
bodyEquality :: Eq b => ResponseEquality b
bodyEquality = ResponseEquality ((==) `on` responseBody)

jsonEquality :: (JsonEq b) => ResponseEquality b
jsonEquality = ResponseEquality (jsonEq `on` responseBody)

class JsonEq a where
  decode' :: a -> Maybe Value
  jsonEq :: a -> a -> Bool
  jsonEq first second = compareDecodedResponses (decode' first) (decode' second)

instance JsonEq LB.ByteString where
  decode' = decode

instance JsonEq ByteString where
  decode' = decodeStrict

compareDecodedResponses :: Maybe Value -> Maybe Value -> Bool
compareDecodedResponses resp1 resp2 =
  case resp1 of
    Nothing -> False  -- if decoding fails we assume failure
    (Just r1) -> case resp2 of
      Nothing -> False  -- another decode failure
      (Just r2) -> r1 == r2
