{-# LANGUAGE RankNTypes #-}

module CPI.Kubernetes.Resource.Metadata(
    name
  , label
  , labels
) where

import           Control.Lens

import           Data.Aeson.Lens
import           Data.Aeson.Types
import qualified Data.HashMap.Strict            as HashMap
import           Data.Maybe
import           Data.Text

import           Kubernetes.Model.V1.Any        (Any)
import qualified Kubernetes.Model.V1.Any        as Any
import           Kubernetes.Model.V1.ObjectMeta (ObjectMeta, mkObjectMeta)
import qualified Kubernetes.Model.V1.ObjectMeta as ObjectMeta
import           Kubernetes.Model.V1.Pod        (Pod)
import qualified Kubernetes.Model.V1.Pod        as Pod
import           Kubernetes.Model.V1.Secret     (Secret)
import qualified Kubernetes.Model.V1.Secret     as Secret
import           Kubernetes.Model.V1.Service    (Service)
import qualified Kubernetes.Model.V1.Service    as Service

class HasMetadata m where
  metadata :: Traversal' m (Maybe ObjectMeta)

instance HasMetadata Pod where
  metadata = Pod.metadata
instance HasMetadata Secret where
  metadata = Secret.metadata
instance HasMetadata Service where
  metadata = Service.metadata

name :: (HasMetadata m) => Traversal' m Text
name = metadata.non mkObjectMeta.ObjectMeta.name.non ""

label :: (HasMetadata m) => Text -> Traversal' m Text
label l = labels.at l.non ""._String

labels :: (HasMetadata m) => Traversal' m Object
labels = metadata.non mkObjectMeta.ObjectMeta.labels.non (Any.Any HashMap.empty).Any.any