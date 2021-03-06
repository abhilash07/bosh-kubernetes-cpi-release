module CPI.Kubernetes.Base64(
    encodeJSON
  , decodeJSON
) where

import qualified CPI.Base               as Base

import           Control.Exception.Safe
import qualified Data.Aeson             as Aeson
import           Data.Aeson.Types
import           Data.ByteString        (ByteString)
import qualified Data.ByteString.Base64 as Base64
import           Data.ByteString.Lazy   (fromStrict, toStrict)
import           Data.Text              (Text)
import qualified Data.Text              as Text
import           Data.Text.Encoding

encodeJSON :: (ToJSON j) => j -> Text
encodeJSON = decodeUtf8 . Base64.encode . toStrict . Aeson.encode

decodeJSON :: (MonadThrow m, FromJSON j) => Text -> m j
decodeJSON = either (throwM . Base.CloudError . Text.pack) pure . Aeson.eitherDecodeStrict . Base64.decodeLenient . encodeUtf8
