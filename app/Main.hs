{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad (forM_, when)
import Crypto.Error (CryptoFailable (..))
import Crypto.Hash (Digest, SHA256, hash)
import qualified Crypto.PubKey.Ed25519 as Ed
import Data.Aeson ((.:), (.:?), (.!=))
import qualified Data.Aeson as A
import qualified Data.Aeson.Types as A
import Data.Bifunctor (first)
import Data.Bits ((.&.), (.|.), shiftR)
import Data.ByteArray (convert)
import Data.ByteArray.Encoding (Base (Base16), convertFromBase, convertToBase)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Lazy as BL
import Data.Char (isSpace)
import Data.Foldable (foldl')
import Data.List (sortBy, sortOn)
import qualified Data.Map.Strict as M
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe, isJust)
import qualified Data.Set as S
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Word (Word8)
import qualified Options.Applicative as OA
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import System.Exit (exitFailure, exitSuccess)
import System.FilePath ((</>))
import System.IO (stdout)

import qualified Codec.CBOR.Encoding as Cbor
import qualified Codec.CBOR.Write as Cbor

newtype Hash = Hash {unHash :: BS.ByteString} deriving (Eq, Ord)
newtype PeerID = PeerID {unPeerID :: BS.ByteString} deriving (Eq, Ord)
newtype Sig = Sig {unSig :: BS.ByteString} deriving (Eq, Ord)
newtype Tm = Tm {unTm :: Integer} deriving (Eq, Ord, Show)

type Realm = Text
type Topic = Text

ftfCliVersion :: String
ftfCliVersion = "0.1.0"

ftfProtocolVersion :: Int
ftfProtocolVersion = 1

ftfMsgDomainTag :: BS.ByteString
ftfMsgDomainTag = "ftf-msg-v1"

instance Show Hash where
  show = BSC.unpack . toHex . unHash

instance Show PeerID where
  show = BSC.unpack . toHex . unPeerID

instance Show Sig where
  show = BSC.unpack . toHex . unSig

data Body
  = Put PutBody
  | Use UseBody
  | Xform XformBody
  | Attest AttestBody
  | Revoke RevokeBody
  | AliasClaim AliasClaimBody
  deriving (Eq, Show)

data PutBody = PutBody
  { putHash :: Hash
  } deriving (Eq, Show)

data UseBody = UseBody
  { useInputs :: [Hash]
  , usePurpose :: Text
  } deriving (Eq, Show)

data XformBody = XformBody
  { xfToolId :: Hash
  , xfToolVersion :: Text
  , xfParamsHash :: Hash
  , xfInputs :: [Hash]
  , xfOutputs :: [Hash]
  , xfRecipeHash :: Hash
  , xfEnvHash :: Hash
  } deriving (Eq, Show)

data AttestBody = AttestBody
  { atAbout :: Hash
  , atClaim :: Text
  , atEvidence :: [Hash]
  } deriving (Eq, Show)

data RevokeBody = RevokeBody
  { rvTarget :: Hash
  , rvReason :: Text
  , rvSupersededBy :: Maybe Hash
  } deriving (Eq, Show)

data AliasClaimBody = AliasClaimBody
  { alId :: Text
  , alTargetHash :: Hash
  , alPrevAliasHash :: Maybe Hash
  , alNote :: Maybe Text
  } deriving (Eq, Show)

data Msg = Msg
  { mV :: Int
  , mRealm :: Realm
  , mTopic :: Topic
  , mPrev :: Maybe Hash
  , mT :: Tm
  , mAuthor :: PeerID
  , mCaps :: [Text]
  , mBody :: Body
  , mWitness :: Maybe Hash
  , mSig :: Sig
  } deriving (Eq, Show)

blankSig :: Msg -> Msg
blankSig m = m {mSig = Sig BS.empty}

setSig :: Sig -> Msg -> Msg
setSig s m = m {mSig = s}

cborMsg :: Msg -> Cbor.Encoding
cborMsg m =
  Cbor.encodeListLen 10
    <> Cbor.encodeInt (fromIntegral (mV m))
    <> Cbor.encodeString (mRealm m)
    <> Cbor.encodeString (mTopic m)
    <> encodeMaybeHash (mPrev m)
    <> Cbor.encodeInteger (unTm (mT m))
    <> Cbor.encodeBytes (unPeerID (mAuthor m))
    <> encodeTextList (mCaps m)
    <> cborBody (mBody m)
    <> encodeMaybeHash (mWitness m)
    <> Cbor.encodeBytes (unSig (mSig m))

cborBody :: Body -> Cbor.Encoding
cborBody = \case
  Put b ->
    Cbor.encodeListLen 2
      <> Cbor.encodeInt 1
      <> Cbor.encodeBytes (unHash (putHash b))
  Use b ->
    Cbor.encodeListLen 3
      <> Cbor.encodeInt 2
      <> encodeHashList (useInputs b)
      <> Cbor.encodeString (usePurpose b)
  Xform b ->
    Cbor.encodeListLen 8
      <> Cbor.encodeInt 3
      <> Cbor.encodeBytes (unHash (xfToolId b))
      <> Cbor.encodeString (xfToolVersion b)
      <> Cbor.encodeBytes (unHash (xfParamsHash b))
      <> encodeHashList (xfInputs b)
      <> encodeHashList (xfOutputs b)
      <> Cbor.encodeBytes (unHash (xfRecipeHash b))
      <> Cbor.encodeBytes (unHash (xfEnvHash b))
  Attest b ->
    Cbor.encodeListLen 4
      <> Cbor.encodeInt 4
      <> Cbor.encodeBytes (unHash (atAbout b))
      <> Cbor.encodeString (atClaim b)
      <> encodeHashList (atEvidence b)
  Revoke b ->
    Cbor.encodeListLen 4
      <> Cbor.encodeInt 5
      <> Cbor.encodeBytes (unHash (rvTarget b))
      <> Cbor.encodeString (rvReason b)
      <> encodeMaybeHash (rvSupersededBy b)
  AliasClaim b ->
    Cbor.encodeListLen 5
      <> Cbor.encodeInt 6
      <> Cbor.encodeString (alId b)
      <> Cbor.encodeBytes (unHash (alTargetHash b))
      <> encodeMaybeHash (alPrevAliasHash b)
      <> encodeMaybeText (alNote b)

encodeMaybeHash :: Maybe Hash -> Cbor.Encoding
encodeMaybeHash = \case
  Nothing -> Cbor.encodeNull
  Just h -> Cbor.encodeBytes (unHash h)

encodeMaybeText :: Maybe Text -> Cbor.Encoding
encodeMaybeText = \case
  Nothing -> Cbor.encodeNull
  Just t -> Cbor.encodeString t

encodeTextList :: [Text] -> Cbor.Encoding
encodeTextList xs =
  Cbor.encodeListLen (fromIntegral (length xs))
    <> mconcat [Cbor.encodeString x | x <- xs]

encodeHashList :: [Hash] -> Cbor.Encoding
encodeHashList hs =
  Cbor.encodeListLen (fromIntegral (length hs))
    <> mconcat [Cbor.encodeBytes (unHash h) | h <- hs]

domainPrefix :: BS.ByteString
domainPrefix = BS.snoc ftfMsgDomainTag 0x00

mhMsg :: Msg -> Hash
mhMsg m =
  let payload = BL.toStrict (Cbor.toLazyByteString (cborMsg (blankSig m)))
      preimage = BS.concat [domainPrefix, payload]
      digest = sha256Bytes preimage
      rawMh = BS.concat [varint 0x12, varint 32, digest]
   in Hash rawMh

sha256Bytes :: BS.ByteString -> BS.ByteString
sha256Bytes = convert . (hash :: BS.ByteString -> Digest SHA256)

varint :: Int -> BS.ByteString
varint n
  | n < 0 = error "negative varint"
  | otherwise = BS.pack (go n)
 where
  go :: Int -> [Word8]
  go x =
    let b = x .&. 0x7F
        rest = x `shiftR` 7
     in if rest == 0
          then [fromIntegral b]
          else fromIntegral (b .|. 0x80) : go rest

data Store = Store
  { stMsgs :: Map Hash Msg
  , stTopics :: Map (Realm, Topic) (Set Hash)
  }

emptyStore :: Store
emptyStore = Store M.empty M.empty

insertMsg :: Store -> Msg -> Store
insertMsg st m =
  let h = mhMsg m
      key = (mRealm m, mTopic m)
      nextTopic = S.insert h (fromMaybe S.empty (M.lookup key (stTopics st)))
   in st
        { stMsgs = M.insert h m (stMsgs st)
        , stTopics = M.insert key nextTopic (stTopics st)
        }

data RejectReason
  = RMissingMsg
  | RHashMismatch
  | RBadSig Text
  | RMissingPrev
  | RPrevRealmTopicMismatch
  | RNonMonotoneT
  deriving (Eq, Show)

verifySig :: PeerID -> Hash -> Sig -> Either Text ()
verifySig (PeerID pkBytes) (Hash mhBytes) (Sig sigBytes) = do
  pk <- first (T.pack . show) $ case Ed.publicKey pkBytes of
    CryptoPassed x -> Right x
    CryptoFailed e -> Left e
  sg <- first (T.pack . show) $ case Ed.signature sigBytes of
    CryptoPassed x -> Right x
    CryptoFailed e -> Left e
  if Ed.verify pk mhBytes sg then Right () else Left "signature verification failed"

parseSecretKey :: BS.ByteString -> Either Text Ed.SecretKey
parseSecretKey skBytes
  | BS.length skBytes == 32 =
      first (T.pack . show) $
        case Ed.secretKey skBytes of
          CryptoPassed sk -> Right sk
          CryptoFailed e -> Left e
  | BS.length skBytes == 64 = do
      let seed = BS.take 32 skBytes
          suffixPk = BS.drop 32 skBytes
      sk <- first (T.pack . show) $
        case Ed.secretKey seed of
          CryptoPassed x -> Right x
          CryptoFailed e -> Left e
      let derivedPk = convert (Ed.toPublic sk) :: BS.ByteString
      if suffixPk == derivedPk
        then Right sk
        else Left "64-byte secret key suffix does not match derived public key"
  | otherwise = Left "secret key must be 32-byte seed or 64-byte (seed||public)"

parsePublicKey :: BS.ByteString -> Either Text Ed.PublicKey
parsePublicKey pkBytes =
  first (T.pack . show) $
    case Ed.publicKey pkBytes of
      CryptoPassed pk -> Right pk
      CryptoFailed e -> Left e

peerIDToPublicKey :: PeerID -> Either Text Ed.PublicKey
peerIDToPublicKey = parsePublicKey . unPeerID

signMh :: Ed.SecretKey -> Hash -> Sig
signMh sk (Hash mhBytes) =
  let pk = Ed.toPublic sk
      sigBytes = convert (Ed.sign sk pk mhBytes) :: BS.ByteString
   in Sig sigBytes

verifyMsg :: Store -> Hash -> Either RejectReason ()
verifyMsg st h = do
  m <- maybe (Left RMissingMsg) Right (M.lookup h (stMsgs st))
  when (mhMsg m /= h) (Left RHashMismatch)
  case verifySig (mAuthor m) h (mSig m) of
    Left e -> Left (RBadSig e)
    Right () ->
      case mPrev m of
        Nothing -> Right ()
        Just prevH -> do
          prevMsg <- maybe (Left RMissingPrev) Right (M.lookup prevH (stMsgs st))
          when ((mRealm prevMsg, mTopic prevMsg) /= (mRealm m, mTopic m)) (Left RPrevRealmTopicMismatch)
          when (mT m <= mT prevMsg) (Left RNonMonotoneT)
          Right ()

topicReplay :: Store -> Realm -> Topic -> ([(Hash, Msg)], [(Hash, RejectReason)])
topicReplay st r tp =
  let hs = S.toList (fromMaybe S.empty (M.lookup (r, tp) (stTopics st)))
      step (oks, bads) h =
        case verifyMsg st h of
          Right () -> case M.lookup h (stMsgs st) of
            Nothing -> (oks, (h, RMissingMsg) : bads)
            Just m -> ((h, m) : oks, bads)
          Left rr -> (oks, (h, rr) : bads)
      (oks0, bads0) = foldl' step ([], []) hs
      key (h, m) = (mT m, unHash h)
   in (sortOn key oks0, sortOn (unHash . fst) bads0)

data AliasStatus = AliasOK | AliasPendingFetch Hash deriving (Eq, Show)

data AliasEntry = AliasEntry
  { aeHead :: Hash
  , aeTarget :: Hash
  , aeStatus :: AliasStatus
  }

data Quarantine = Quarantine
  { qHash :: Hash
  , qReason :: Text
  }

type AliasState = Map Text AliasEntry

data MsgRef = MsgRef
  { mrHash :: Hash
  , mrT :: Tm
  , mrAuthor :: PeerID
  , mrBody :: Body
  } deriving (Eq, Show)

data GraphIndex = GraphIndex
  { giPutByArtifact :: Map Hash [MsgRef]
  , giXformsByOutput :: Map Hash [MsgRef]
  , giXformInputs :: Map Hash [Hash]
  , giUseByInput :: Map Hash [MsgRef]
  , giAttestByAbout :: Map Hash [MsgRef]
  , giRevokeByTarget :: Map Hash [MsgRef]
  }

emptyGraphIndex :: GraphIndex
emptyGraphIndex =
  GraphIndex M.empty M.empty M.empty M.empty M.empty M.empty

appendMapList :: Ord k => k -> a -> Map k [a] -> Map k [a]
appendMapList k v = M.alter f k
 where
  f Nothing = Just [v]
  f (Just xs) = Just (v : xs)

indexVerifiedMsgs :: [(Hash, Msg)] -> GraphIndex
indexVerifiedMsgs = foldl' step emptyGraphIndex
 where
  step gi (h, m) =
    let ref = MsgRef h (mT m) (mAuthor m) (mBody m)
     in case mBody m of
          Put pb ->
            gi {giPutByArtifact = appendMapList (putHash pb) ref (giPutByArtifact gi)}
          Use ub ->
            gi {giUseByInput = foldl' (\acc i -> appendMapList i ref acc) (giUseByInput gi) (useInputs ub)}
          Xform xb ->
            gi
              { giXformsByOutput = foldl' (\acc out -> appendMapList out ref acc) (giXformsByOutput gi) (xfOutputs xb)
              , giXformInputs = M.insert h (xfInputs xb) (giXformInputs gi)
              }
          Attest ab ->
            gi {giAttestByAbout = appendMapList (atAbout ab) ref (giAttestByAbout gi)}
          Revoke rb ->
            gi {giRevokeByTarget = appendMapList (rvTarget rb) ref (giRevokeByTarget gi)}
          AliasClaim _ -> gi

data EdgeRec = EdgeRec
  { erFrom :: Text
  , erTo :: Text
  , erRel :: Text
  } deriving (Eq, Ord, Show)

data NoteRec = NoteRec
  { nrAbout :: Text
  , nrType :: Text
  , nrRef :: MsgRef
  } deriving (Eq, Show)

resolveAliases :: Set Hash -> Store -> Realm -> Topic -> (AliasState, [Quarantine])
resolveAliases casSet st r aliasTopic =
  let (replay, _) = topicReplay st r aliasTopic
   in foldl' apply (M.empty, []) replay
 where
  apply (state, qs) (h, m) =
    case mBody m of
      AliasClaim ac ->
        let status =
              if S.member (alTargetHash ac) casSet
                then AliasOK
                else AliasPendingFetch (alTargetHash ac)
            addQ reason = (state, Quarantine h reason : qs)
         in case M.lookup (alId ac) state of
              Nothing ->
                case alPrevAliasHash ac of
                  Nothing ->
                    ( M.insert (alId ac) (AliasEntry h (alTargetHash ac) status) state
                    , qs
                    )
                  Just _ -> addQ "first claim must set prev_alias_hash = null"
              Just cur ->
                if alPrevAliasHash ac == Just (aeHead cur)
                  then
                    ( M.insert (alId ac) (AliasEntry h (alTargetHash ac) status) state
                    , qs
                    )
                  else addQ "prev_alias_hash mismatch / fork"
      _ -> (state, qs)

lookupAlias :: AliasState -> Text -> Maybe AliasEntry
lookupAlias = flip M.lookup

hashText :: Hash -> Text
hashText = TE.decodeUtf8 . toHex . unHash

peerText :: PeerID -> Text
peerText = TE.decodeUtf8 . toHex . unPeerID

artifactRef :: Hash -> Text
artifactRef h = "artifact:" <> hashText h

eventRef :: Hash -> Text
eventRef h = "event:" <> hashText h

msgRefCmp :: MsgRef -> MsgRef -> Ordering
msgRefCmp a b = compare (mrT a, unHash (mrHash a)) (mrT b, unHash (mrHash b))

msgRefToEventValue :: MsgRef -> A.Value
msgRefToEventValue ref =
  let base =
        [ "kind" A..= ("trace.event" :: Text)
        , "mh" A..= hashText (mrHash ref)
        , "t" A..= unTm (mrT ref)
        , "author" A..= peerText (mrAuthor ref)
        ]
   in case mrBody ref of
        Put pb ->
          A.object
            ( base
                ++ [ "etype" A..= ("put" :: Text)
                   , "artifact" A..= hashText (putHash pb)
                   ]
            )
        Use ub ->
          A.object
            ( base
                ++ [ "etype" A..= ("use" :: Text)
                   , "inputs" A..= map hashText (sortOn unHash (useInputs ub))
                   , "purpose" A..= usePurpose ub
                   ]
            )
        Xform xb ->
          A.object
            ( base
                ++ [ "etype" A..= ("xform" :: Text)
                   , "tool" A..= hashText (xfToolId xb)
                   , "inputs" A..= map hashText (sortOn unHash (xfInputs xb))
                   , "outputs" A..= map hashText (sortOn unHash (xfOutputs xb))
                   ]
            )
        Attest ab ->
          A.object
            ( base
                ++ [ "etype" A..= ("attest" :: Text)
                   , "about" A..= hashText (atAbout ab)
                   , "claim" A..= atClaim ab
                   ]
            )
        Revoke rb ->
          A.object
            ( base
                ++ [ "etype" A..= ("revoke" :: Text)
                   , "target" A..= hashText (rvTarget rb)
                   , "reason" A..= rvReason rb
                   ]
            )
        AliasClaim ab ->
          A.object
            ( base
                ++ [ "etype" A..= ("alias_claim" :: Text)
                   , "id" A..= alId ab
                   , "target_hash" A..= hashText (alTargetHash ab)
                   ]
            )

noteToValue :: NoteRec -> A.Value
noteToValue nr =
  let ref = nrRef nr
      base =
        [ "kind" A..= ("trace.note" :: Text)
        , "about" A..= nrAbout nr
        , "note_type" A..= nrType nr
        , "mh" A..= hashText (mrHash ref)
        , "t" A..= unTm (mrT ref)
        , "author" A..= peerText (mrAuthor ref)
        ]
   in case mrBody ref of
        Attest ab -> A.object (base ++ ["claim" A..= atClaim ab])
        Revoke rb -> A.object (base ++ ["reason" A..= rvReason rb])
        _ -> A.object base

traceArtifact :: Set Hash -> Hash -> Bool -> A.Value
traceArtifact casSet h isRoot =
  let present = S.member h casSet
      status = if present then ("ok" :: Text) else "pending_fetch"
   in A.object
        [ "kind" A..= ("trace.artifact" :: Text)
        , "h" A..= hashText h
        , "role" A..= (if isRoot then ("root" :: Text) else "dependency")
        , "status" A..= status
        ]

traceEdge :: EdgeRec -> A.Value
traceEdge e =
  A.object
    [ "kind" A..= ("trace.edge" :: Text)
    , "from" A..= erFrom e
    , "to" A..= erTo e
    , "rel" A..= erRel e
    ]

buildTrace :: Set Hash -> GraphIndex -> Hash -> Either Text [A.Value]
buildTrace casSet gi root =
  if not rootExists
    then Left "root artifact not found in verified put/xform outputs"
    else Right (header ++ artifactVals ++ eventVals ++ noteVals ++ edgeVals)
 where
  rootExists = isJust (M.lookup root (giPutByArtifact gi)) || isJust (M.lookup root (giXformsByOutput gi))

  go pending seenArtifacts seenEvents eventMap edgeSet noteMap
    | S.null pending = (seenArtifacts, seenEvents, eventMap, edgeSet, noteMap)
    | otherwise =
        let (h, pendingRest) = S.deleteFindMin pending
         in if S.member h seenArtifacts
              then go pendingRest seenArtifacts seenEvents eventMap edgeSet noteMap
              else
                let seenArtifacts' = S.insert h seenArtifacts
                    producersX = sortBy msgRefCmp (M.findWithDefault [] h (giXformsByOutput gi))
                    producers = if null producersX then sortBy msgRefCmp (M.findWithDefault [] h (giPutByArtifact gi)) else producersX
                    uses = sortBy msgRefCmp (M.findWithDefault [] h (giUseByInput gi))
                    (pending2, seenEvents2, eventMap2, edgeSet2, noteMap2) =
                      foldl'
                        (processRef h)
                        (pendingRest, seenEvents, eventMap, edgeSet, noteMap)
                        (producers ++ uses)
                    noteMap3 = addAboutNotes (artifactRef h) h noteMap2
                 in go pending2 seenArtifacts' seenEvents2 eventMap2 edgeSet2 noteMap3

  processRef h (pending, seenEvents, eventMap, edgeSet, noteMap) ref =
    let eId = eventRef (mrHash ref)
        aId = artifactRef h
        isNewEvent = S.notMember (mrHash ref) seenEvents
        seenEvents' = S.insert (mrHash ref) seenEvents
        eventMap' = if isNewEvent then M.insert (mrHash ref) ref eventMap else eventMap
        noteMap' = if isNewEvent then addAboutNotes eId (mrHash ref) noteMap else noteMap
        (edgeSet1, pending1) =
          case mrBody ref of
            Xform xb ->
              let edgesA = S.insert (EdgeRec eId aId "produces") edgeSet
                  ins = sortOn unHash (xfInputs xb)
                  edgesB = foldl' (\acc i -> S.insert (EdgeRec (artifactRef i) eId "consumed_by") acc) edgesA ins
                  pending' = foldl' (flip S.insert) pending ins
               in (edgesB, pending')
            Put _ ->
              (S.insert (EdgeRec eId aId "produces") edgeSet, pending)
            Use _ ->
              (S.insert (EdgeRec aId eId "used_by") edgeSet, pending)
            _ ->
              (edgeSet, pending)
     in (pending1, seenEvents', eventMap', edgeSet1, noteMap')

  addAboutNotes aboutLabel aboutHash noteMap =
    let atts = M.findWithDefault [] aboutHash (giAttestByAbout gi)
        revs = M.findWithDefault [] aboutHash (giRevokeByTarget gi)
        refs = atts ++ revs
     in foldl' addOne noteMap refs
   where
    addOne nm ref =
      let ntype = case mrBody ref of
            Attest _ -> "attest"
            Revoke _ -> "revoke"
            _ -> "note"
          key = (aboutLabel, ntype, mrHash ref)
       in if M.member key nm
            then nm
            else
              let nr = NoteRec aboutLabel ntype ref
               in M.insert key nr nm

  (artifactSet, _, eventMapFinal, edgeSetFinal, noteMapFinal) =
    go (S.singleton root) S.empty S.empty M.empty S.empty M.empty

  header = [A.object ["kind" A..= ("trace.header" :: Text), "root" A..= hashText root, "version" A..= (1 :: Int)]]
  artifactVals =
    map (\h -> traceArtifact casSet h (h == root)) (S.toAscList artifactSet)
  eventVals =
    map msgRefToEventValue (sortBy msgRefCmp (M.elems eventMapFinal))
  noteVals =
    map noteToValue (sortBy noteCmp (M.elems noteMapFinal))
      ++ map pendingFetchNote (S.toAscList (S.filter (\h -> S.notMember h casSet) artifactSet))
  edgeVals =
    map traceEdge (S.toAscList edgeSetFinal)

  noteCmp a b =
    compare (mrT (nrRef a), unHash (mrHash (nrRef a)), nrAbout a, nrType a)
            (mrT (nrRef b), unHash (mrHash (nrRef b)), nrAbout b, nrType b)

  pendingFetchNote h =
    A.object
      [ "kind" A..= ("trace.note" :: Text)
      , "about" A..= artifactRef h
      , "note_type" A..= ("pending_fetch" :: Text)
      ]

instance A.FromJSON Hash where
  parseJSON = A.withText "Hash(hex)" $ \t ->
    Hash <$> either fail pure (fromHex (TE.encodeUtf8 t))

instance A.FromJSON PeerID where
  parseJSON = A.withText "PeerID(hex)" $ \t ->
    PeerID <$> either fail pure (fromHex (TE.encodeUtf8 t))

instance A.FromJSON Sig where
  parseJSON = A.withText "Sig(hex)" $ \t ->
    Sig <$> either fail pure (fromHex (TE.encodeUtf8 t))

instance A.FromJSON Tm where
  parseJSON = A.withScientific "t" $ \n -> pure (Tm (round n))

instance A.FromJSON Msg where
  parseJSON = A.withObject "Msg" $ \o ->
    Msg
      <$> o .: "v"
      <*> o .: "realm"
      <*> o .: "topic"
      <*> o .:? "prev"
      <*> o .: "t"
      <*> o .: "author"
      <*> o .:? "caps" .!= []
      <*> o .: "body"
      <*> o .:? "witness"
      <*> o .: "sig"

instance A.FromJSON Body where
  parseJSON = A.withObject "Body" $ \o -> do
    kind <- o .: "kind" :: A.Parser Text
    case kind of
      "put" -> do
        art <- o .: "artifact"
        Put <$> (PutBody <$> art .: "hash")
      "use" -> Use <$> (UseBody <$> o .: "inputs" <*> o .: "purpose")
      "xform" -> do
        tool <- o .: "tool"
        receipt <- o .: "receipt"
        Xform
          <$> ( XformBody
                  <$> tool .: "id"
                  <*> tool .: "version"
                  <*> tool .: "params_hash"
                  <*> o .: "inputs"
                  <*> o .: "outputs"
                  <*> receipt .: "recipe_hash"
                  <*> receipt .: "env_hash"
              )
      "attest" -> Attest <$> (AttestBody <$> o .: "about" <*> o .: "claim" <*> o .:? "evidence" .!= [])
      "revoke" -> Revoke <$> (RevokeBody <$> o .: "target" <*> o .: "reason" <*> o .:? "superseded_by")
      "alias_claim" ->
        AliasClaim
          <$> ( AliasClaimBody
                  <$> o .: "id"
                  <*> o .: "target_hash"
                  <*> o .:? "prev_alias_hash"
                  <*> o .:? "note"
              )
      _ -> fail ("unknown body.kind: " <> T.unpack kind)

data Cmd
  = CmdVersion
  | CmdHashMsg FilePath
  | CmdSignMsg BS.ByteString FilePath
  | CmdGenKeypair
  | CmdSelfTest
  | CmdTrace Realm Topic BS.ByteString FilePath
  | CmdCasPut FilePath
  | CmdCasHas BS.ByteString
  | CmdCasGet BS.ByteString
  | CmdVerifyTopic Realm Topic FilePath
  | CmdResolveAlias Realm Topic Text FilePath

cmdParser :: OA.Parser Cmd
cmdParser =
  OA.hsubparser
    ( OA.command
        "version"
        (OA.info versionP (OA.progDesc "Print CLI and protocol version info"))
        <> OA.command
        "hash-msg"
        (OA.info hashP (OA.progDesc "Hash one NDJSON message as multihash sha2-256"))
        <> OA.command
          "sign-msg"
          (OA.info signP (OA.progDesc "Sign one NDJSON message using Ed25519 over raw mh bytes"))
        <> OA.command
          "gen-keypair"
          (OA.info genP (OA.progDesc "Generate an Ed25519 keypair (hex output)"))
        <> OA.command
          "selftest"
          (OA.info selfTestP (OA.progDesc "Run golden vector checks for mh/signature determinism"))
        <> OA.command
          "trace"
          (OA.info traceP (OA.progDesc "Emit deterministic lineage NDJSON for an artifact hash"))
        <> OA.command
          "cas-put"
          (OA.info casPutP (OA.progDesc "Store blob in local CAS and print its multihash"))
        <> OA.command
          "cas-has"
          (OA.info casHasP (OA.progDesc "Exit 0 if local CAS contains the given multihash"))
        <> OA.command
          "cas-get"
          (OA.info casGetP (OA.progDesc "Write blob bytes from local CAS to stdout"))
        <> OA.command
          "verify-topic"
          (OA.info verifyP (OA.progDesc "Verify K2/K3/K4 and print verified/rejected counts"))
        <> OA.command
          "resolve-alias"
          (OA.info resolveP (OA.progDesc "Resolve logical id from alias topic using deterministic replay"))
    )
 where
  versionP = pure CmdVersion
  hashP = CmdHashMsg <$> OA.strArgument (OA.metavar "MSG.ndjson")
  signP =
    CmdSignMsg
      <$> OA.option
        (OA.eitherReader (\s -> fromHex (TE.encodeUtf8 (T.pack s))))
        (OA.long "sk" <> OA.metavar "SECRET_KEY_HEX")
      <*> OA.strArgument (OA.metavar "MSG.ndjson")
  genP = pure CmdGenKeypair
  selfTestP = pure CmdSelfTest
  traceP =
    CmdTrace
      <$> OA.option OA.str (OA.long "realm" <> OA.metavar "REALM")
      <*> OA.option OA.str (OA.long "topic" <> OA.metavar "TOPIC")
      <*> OA.argument
        (OA.eitherReader (\s -> fromHex (TE.encodeUtf8 (T.pack s))))
        (OA.metavar "ARTIFACT_MH_HEX")
      <*> OA.strArgument (OA.metavar "TOPIC.ndjson")
  casPutP = CmdCasPut <$> OA.strArgument (OA.metavar "PATH")
  casHasP =
    CmdCasHas
      <$> OA.argument
        (OA.eitherReader (\s -> fromHex (TE.encodeUtf8 (T.pack s))))
        (OA.metavar "MH_HEX")
  casGetP =
    CmdCasGet
      <$> OA.argument
        (OA.eitherReader (\s -> fromHex (TE.encodeUtf8 (T.pack s))))
        (OA.metavar "MH_HEX")
  verifyP =
    CmdVerifyTopic
      <$> OA.option OA.str (OA.long "realm" <> OA.metavar "REALM")
      <*> OA.option OA.str (OA.long "topic" <> OA.metavar "TOPIC")
      <*> OA.strArgument (OA.metavar "TOPIC.ndjson")
  resolveP =
    CmdResolveAlias
      <$> OA.option OA.str (OA.long "realm" <> OA.metavar "REALM")
      <*> OA.option OA.str (OA.long "topic" <> OA.metavar "ALIAS_TOPIC")
      <*> OA.option OA.str (OA.long "id" <> OA.metavar "LOGICAL_ID")
      <*> OA.strArgument (OA.metavar "ALIAS.ndjson")

main :: IO ()
main = do
  cmd <- OA.execParser (OA.info (cmdParser OA.<**> OA.helper) OA.fullDesc)
  run cmd

run :: Cmd -> IO ()
run = \case
  CmdVersion -> do
    putStrLn ("ftf_cli_version=" <> ftfCliVersion)
    putStrLn ("ftf_protocol_version=" <> show ftfProtocolVersion)
    putStrLn ("ftf_msg_domain_tag=" <> BSC.unpack ftfMsgDomainTag)
    putStrLn "ftf_preimage_prefix=ftf-msg-v1\\0"
  CmdHashMsg fp -> do
    m <- readOneMsg fp
    putStrLn (show (mhMsg m))
  CmdSignMsg skHex fp -> do
    m <- readOneMsg fp
    sk <- either (fail . T.unpack) pure (parseSecretKey skHex)
    authorPk <- either (fail . T.unpack) pure (peerIDToPublicKey (mAuthor m))
    let expectedAuthor = convert (Ed.toPublic sk) :: BS.ByteString
    when (convert authorPk /= expectedAuthor) $
      fail "author does not match --sk public key (fail-closed)"
    let msgHash = mhMsg m
        signed = setSig (signMh sk msgHash) m
    BSC.putStrLn (BL.toStrict (A.encode signed))
  CmdGenKeypair -> do
    seed <- Ed.generateSecretKey
    let pk = convert (Ed.toPublic seed) :: BS.ByteString
        skSeed = convert seed :: BS.ByteString
        sk64 = BS.concat [skSeed, pk]
        obj =
          A.object
            [ "pk" A..= TE.decodeUtf8 (toHex pk)
            , "sk_seed" A..= TE.decodeUtf8 (toHex skSeed)
            , "sk" A..= TE.decodeUtf8 (toHex sk64)
            ]
    BSC.putStrLn (BL.toStrict (A.encode obj))
  CmdSelfTest -> do
    let base = "test/vectors/"
        vectorMsg = base <> "alias-claim-1.ndjson"
        vectorMh = base <> "alias-claim-1.mh"
        vectorSig = base <> "alias-claim-1.sig"
        testSeedHex = "72a136dc318533d167df476ff76d511d471177137263b532d15fd5f4200f6101"
    mapM_ requireFile [vectorMsg, vectorMh, vectorSig]
    m <- readOneMsg vectorMsg
    mhExpected <- readHexFileTrim vectorMh
    sigExpected <- readHexFileTrim vectorSig
    skBytes <- either fail pure (fromHex testSeedHex)
    sk <- either (fail . T.unpack) pure (parseSecretKey skBytes)
    let hActual = unHash (mhMsg m)
    when (hActual /= mhExpected) $
      fail ("mh mismatch: expected " <> BSC.unpack (toHex mhExpected) <> ", got " <> BSC.unpack (toHex hActual))
    let sigActual = unSig (signMh sk (mhMsg m))
    when (sigActual /= sigExpected) $
      fail ("sig mismatch: expected " <> BSC.unpack (toHex sigExpected) <> ", got " <> BSC.unpack (toHex sigActual))
    putStrLn "selftest=ok"
  CmdTrace realm topic rootRaw fp -> do
    msgs <- readMsgs fp
    let st = foldl' insertMsg emptyStore msgs
        (verified, _) = topicReplay st realm topic
    when (null verified) $
      fail "no verified messages for realm/topic"
    let gi = indexVerifiedMsgs verified
        root = Hash rootRaw
    casSet <- loadCasSet
    out <- either (fail . T.unpack) pure (buildTrace casSet gi root)
    forM_ out $ \v -> BSC.putStrLn (BL.toStrict (A.encode v))
  CmdCasPut path -> do
    bytes <- BS.readFile path
    let h = mhBlob bytes
    casPut h bytes
    putStrLn (show h)
  CmdCasHas mhRaw -> do
    let h = Hash mhRaw
    ok <- casHas h
    if ok then exitSuccess else exitFailure
  CmdCasGet mhRaw -> do
    let h = Hash mhRaw
    mBlob <- casGet h
    case mBlob of
      Nothing -> fail ("CAS missing blob: " <> show h)
      Just b -> BS.hPut stdout b
  CmdVerifyTopic realm topic fp -> do
    msgs <- readMsgs fp
    let st = foldl' insertMsg emptyStore msgs
        (ok, bad) = topicReplay st realm topic
    putStrLn ("verified=" <> show (length ok))
    forM_ ok $ \(h, m) ->
      putStrLn ("OK " <> show h <> " t=" <> show (unTm (mT m)))
    putStrLn ("rejected=" <> show (length bad))
    forM_ bad $ \(h, rr) ->
      putStrLn ("BAD " <> show h <> " reason=" <> show rr)
  CmdResolveAlias realm aliasTopic lid fp -> do
    msgs <- readMsgs fp
    casSet <- loadCasSet
    let st = foldl' insertMsg emptyStore msgs
        (aliases, qs) = resolveAliases casSet st realm aliasTopic
    putStrLn ("quarantine=" <> show (length qs))
    forM_ (reverse qs) $ \q ->
      putStrLn ("Q " <> show (qHash q) <> " reason=" <> T.unpack (qReason q))
    case lookupAlias aliases lid of
      Nothing -> putStrLn "not_found"
      Just ae -> do
        putStrLn ("target_hash=" <> show (aeTarget ae))
        case aeStatus ae of
          AliasOK -> putStrLn "status=ok"
          AliasPendingFetch h -> putStrLn ("status=pending_fetch " <> show h)

readMsgs :: FilePath -> IO [Msg]
readMsgs fp = do
  raw <- BSC.readFile fp
  let rows = filter (not . BS.null) (map strip (BSC.lines raw))
  traverse parseLine (zip [1 :: Int ..] rows)
 where
  parseLine (n, line) =
    case A.eitherDecodeStrict' line of
      Left e -> fail ("invalid NDJSON at line " <> show n <> ": " <> e)
      Right m -> pure m

readOneMsg :: FilePath -> IO Msg
readOneMsg fp = do
  msgs <- readMsgs fp
  case msgs of
    [m] -> pure m
    [] -> fail "no parsable NDJSON message found"
    _ -> fail "expected exactly one NDJSON line"

strip :: BS.ByteString -> BS.ByteString
strip = dropWhileEnd isSpace8 . BS.dropWhile isSpace8
 where
  isSpace8 = isSpace . toEnum . fromEnum
  dropWhileEnd p = BS.reverse . BS.dropWhile p . BS.reverse

toHex :: BS.ByteString -> BS.ByteString
toHex = convertToBase Base16

fromHex :: BS.ByteString -> Either String BS.ByteString
fromHex = first show . convertFromBase Base16

casRoot :: FilePath
casRoot = ".ftf/cas"

casPath :: Hash -> FilePath
casPath h = casRoot </> BSC.unpack (toHex (unHash h))

ensureCasDir :: IO ()
ensureCasDir = createDirectoryIfMissing True casRoot

casPut :: Hash -> BS.ByteString -> IO ()
casPut h bytes = do
  ensureCasDir
  let p = casPath h
  exists <- doesFileExist p
  if exists
    then do
      old <- BS.readFile p
      when (old /= bytes) (fail ("CAS collision at " <> p))
    else BS.writeFile p bytes

casHas :: Hash -> IO Bool
casHas h = doesFileExist (casPath h)

casGet :: Hash -> IO (Maybe BS.ByteString)
casGet h = do
  let p = casPath h
  exists <- doesFileExist p
  if exists then Just <$> BS.readFile p else pure Nothing

loadCasSet :: IO (Set Hash)
loadCasSet = do
  exists <- doesDirectoryExist casRoot
  if not exists
    then pure S.empty
    else do
      names <- listDirectory casRoot
      let parsed = map (fromHex . TE.encodeUtf8 . T.pack) names
      pure (S.fromList [Hash b | Right b <- parsed])

mhBlob :: BS.ByteString -> Hash
mhBlob bytes =
  let digest = sha256Bytes bytes
      rawMh = BS.concat [varint 0x12, varint 32, digest]
   in Hash rawMh

readHexFileTrim :: FilePath -> IO BS.ByteString
readHexFileTrim fp = do
  bytes <- BSC.readFile fp
  let cleaned = strip bytes
  either fail pure (fromHex cleaned)

requireFile :: FilePath -> IO ()
requireFile fp = do
  ok <- doesFileExist fp
  when (not ok) (fail ("missing required file: " <> fp))

instance A.ToJSON Hash where
  toJSON = A.String . TE.decodeUtf8 . toHex . unHash

instance A.ToJSON PeerID where
  toJSON = A.String . TE.decodeUtf8 . toHex . unPeerID

instance A.ToJSON Sig where
  toJSON = A.String . TE.decodeUtf8 . toHex . unSig

instance A.ToJSON Tm where
  toJSON (Tm n) = A.Number (fromInteger n)

instance A.ToJSON Msg where
  toJSON m =
    A.object
      [ "v" A..= mV m
      , "realm" A..= mRealm m
      , "topic" A..= mTopic m
      , "prev" A..= mPrev m
      , "t" A..= mT m
      , "author" A..= mAuthor m
      , "caps" A..= mCaps m
      , "body" A..= mBody m
      , "witness" A..= mWitness m
      , "sig" A..= mSig m
      ]

instance A.ToJSON Body where
  toJSON = \case
    Put pb ->
      A.object
        [ "kind" A..= ("put" :: Text)
        , "artifact" A..= A.object ["hash" A..= putHash pb]
        ]
    Use ub ->
      A.object
        [ "kind" A..= ("use" :: Text)
        , "inputs" A..= useInputs ub
        , "purpose" A..= usePurpose ub
        ]
    Xform xb ->
      A.object
        [ "kind" A..= ("xform" :: Text)
        , "tool" A..= A.object
            [ "id" A..= xfToolId xb
            , "version" A..= xfToolVersion xb
            , "params_hash" A..= xfParamsHash xb
            ]
        , "inputs" A..= xfInputs xb
        , "outputs" A..= xfOutputs xb
        , "receipt" A..= A.object
            [ "recipe_hash" A..= xfRecipeHash xb
            , "env_hash" A..= xfEnvHash xb
            ]
        ]
    Attest ab ->
      A.object
        [ "kind" A..= ("attest" :: Text)
        , "about" A..= atAbout ab
        , "claim" A..= atClaim ab
        , "evidence" A..= atEvidence ab
        ]
    Revoke rb ->
      A.object
        [ "kind" A..= ("revoke" :: Text)
        , "target" A..= rvTarget rb
        , "reason" A..= rvReason rb
        , "superseded_by" A..= rvSupersededBy rb
        ]
    AliasClaim ac ->
      A.object
        [ "kind" A..= ("alias_claim" :: Text)
        , "id" A..= alId ac
        , "target_hash" A..= alTargetHash ac
        , "prev_alias_hash" A..= alPrevAliasHash ac
        , "note" A..= alNote ac
        ]
