{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
module CPI.Kubernetes.Resource.Stub.Service(
    Service
  , ServiceList
) where

import           CPI.Base.Errors                     (CloudError (..))
import           CPI.Kubernetes.Config
import           CPI.Kubernetes.Resource.Metadata
import           CPI.Kubernetes.Resource.Servant
import           CPI.Kubernetes.Resource.Service
import           CPI.Kubernetes.Resource.Stub.State
import           Resource

import           Kubernetes.Model.Unversioned.Status (Status)
import           Kubernetes.Model.V1.DeleteOptions   (mkDeleteOptions)
import           Kubernetes.Model.V1.ObjectMeta      (ObjectMeta)
import qualified Kubernetes.Model.V1.ObjectMeta      as ObjectMeta
import           Kubernetes.Model.V1.Service         (Service)
import qualified Kubernetes.Model.V1.Service         as Service
import           Kubernetes.Model.V1.ServiceList     (ServiceList)
import qualified Kubernetes.Model.V1.ServiceList     as ServiceList

import           Kubernetes.Api.ApivApi              (createNamespacedPod,
                                                      deleteNamespacedPod,
                                                      listNamespacedPod,
                                                      readNamespacedPod,
                                                      replaceNamespacedPod)

import           Control.Exception.Safe
import           Control.Lens
import           Control.Lens.Operators
import           Control.Monad.Log
import           Control.Monad.Reader
import qualified Control.Monad.State                 as State
import           Servant.Client

import           Data.Aeson
import           Data.ByteString.Lazy                (toStrict)
import           Data.HashMap.Strict                 (HashMap, insert, (!))
import qualified Data.HashMap.Strict                 as HashMap
import           Data.Hourglass.Types
import           Data.Maybe
import           Data.Semigroup
import           Data.Text                           (Text)
import qualified Data.Text                           as Text
import           Data.Text.Encoding                  (decodeUtf8)


import           Control.Monad.Stub.StubMonad
import           Control.Monad.Stub.Time
import           Control.Monad.Stub.Wait
import           Control.Monad.Time
import           Control.Monad.Wait

import qualified GHC.Int                             as GHC

instance (MonadThrow m, MonadWait m, Monoid w, HasServices s, HasWaitCount w, HasTime s, HasTimeline s) => MonadService (StubT r s w m) where
  createService namespace service = do
    services <- State.gets asServices
    let services' = insert (namespace, service ^. name) service services
    State.modify $ updateServices services'
    pure service

  listService namespace = do
    kube <- State.get
    pure undefined

  getService namespace name = do
    services <- State.gets asServices
    pure $ (namespace, name) `HashMap.lookup` services

  updateService namespace newService = do
    let serviceKey = (namespace, newService ^. name)
    State.modify $ withServices $ \services ->
      if serviceKey `HashMap.member` services
        then
          HashMap.adjust (\service ->
                              service & labels .~ newService ^. labels
                                      & podSelector .~ newService ^. podSelector) serviceKey services
        else services
    fromJust . HashMap.lookup serviceKey <$> State.gets asServices

  deleteService namespace name = do
    timestamp <- currentTime
    State.modify $ withTimeline
                 (\events ->
                   let
                     deleted :: [s -> s]
                     deleted = [withServices $ HashMap.delete (namespace, name)]
                     after :: GHC.Int64 -> Elapsed
                     after n = timestamp + (Elapsed $ Seconds n)
                     in
                       HashMap.insert (after 1) deleted events
                       )
    pure undefined

  waitForService namespace name predicate = waitFor (WaitConfig (Retry 20) (Seconds 1)) (getService namespace name) predicate
